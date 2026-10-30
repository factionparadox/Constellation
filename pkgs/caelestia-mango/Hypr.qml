pragma Singleton

// Constellation: Caelestia's Hyprland service, reimplemented for MangoWM.
// Replaces services/Hypr.qml. It keeps the same names and object shapes the rest of the shell
// reads (workspaces.values, toplevels.values, lastIpcObject.class/at/size/floating/...), but the
// data comes from mango's IPC: `mmsg watch all-monitors` and `mmsg watch all-clients` stream a
// full JSON snapshot on every change, and actions go out as `mmsg dispatch <func>,<args>`.
// Mango's tags (1-9) stand in for Hyprland's workspaces; mango has no Hyprland-style special
// workspaces, so those calls map to its named scratchpad where possible and are ignored otherwise.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.I18n

Singleton {
    id: root

    // --------------------------------------------------------------- the shapes the shell reads
    property var monitors: ({ values: [] })
    property var workspaces: ({ values: [] })
    property var toplevels: ({ values: [] })
    readonly property bool usingLua: false

    readonly property var focusedMonitor: monitors.values.find(m => m.focused) ?? monitors.values[0] ?? null
    readonly property var focusedWorkspace: focusedMonitor?.activeWorkspace ?? null
    readonly property int activeWsId: focusedWorkspace?.id ?? 1
    readonly property var activeToplevel: toplevels.values.find(t => t.focused) ?? null

    // Keyboard: mango reports the active layout name; caps and num lock are not in its IPC.
    readonly property var keyboard: null
    readonly property bool capsLock: false
    readonly property bool numLock: false
    property string kbLayoutFull: Tr.trCtx("Unknown", "keyboard layout")
    readonly property string defaultKbLayout: kbLayout
    readonly property string kbLayout: kbMap.get(kbLayoutFull) ?? (kbLayoutFull.slice(0, 2).toLowerCase() || "??")
    readonly property var kbMap: new Map()

    // Hyprland-only extras (live option editing, device refresh): harmless stand-ins.
    readonly property var extras: QtObject {
        readonly property var options: ({})
        readonly property var devices: ({ keyboards: [] })
        function refreshDevices() {}
        function refreshOptions() {}
        function batchMessage(messages) {}
        function message(text) {}
        function applyOptions(options) {}
    }
    readonly property var options: extras.options
    readonly property var devices: extras.devices

    property string lastSpecialWorkspace: ""
    signal configReloaded

    // --------------------------------------------------------------- actions
    // Accepts the Hyprland dispatch strings the shell sends and translates the ones mango has.
    function dispatch(request: string): void {
        const r = request.trim();
        let m;
        if ((m = r.match(/^workspace\s+r([+-])1$/)))
            mango(m[1] === "+" ? "viewtoright" : "viewtoleft");
        else if ((m = r.match(/^workspace\s+(\d+)$/)))
            mango(`view,${m[1]}`);
        else if ((m = r.match(/^togglespecialworkspace\s*(\S*)$/)))
            toggleSpecial(m[1]);
        else if ((m = r.match(/^movetoworkspace(?:silent)?\s+(\d+)(?:,\s*address:0x([0-9a-f]+))?$/)))
            mango(`tagsilent,${m[1]}` + clientArg(m[2]));
        else if ((m = r.match(/^togglefloating(?:\s+address:0x([0-9a-f]+))?$/)))
            mango("togglefloating" + clientArg(m[1]));
        else if ((m = r.match(/^(?:killactive|closewindow)(?:\s+address:0x([0-9a-f]+))?$/)))
            mango("killclient" + clientArg(m[1]));
        else if ((m = r.match(/^dpms\s+(on|off)$/)))
            for (const mon of monitors.values)
                mango(`${m[1] === "off" ? "sleep_monitor" : "wakeup_monitor"},${mon.name}`);
        else if (r.startsWith("exec "))
            Quickshell.execDetached(["sh", "-c", r.slice(5)]);
        else
            console.log("Hypr (mango): no mango equivalent for dispatch:", r);
    }

    function mango(command: string): void {
        Quickshell.execDetached(["mmsg", "dispatch", ...command.split(" ")]);
    }

    // Toplevel "addresses" are mango client ids written as hex, so they round-trip here.
    function clientArg(address): string {
        return address ? ` client,${parseInt(address, 16)}` : "";
    }

    function focusWorkspace(ws: var): void {
        const n = parseInt(ws);
        if (!isNaN(n))
            mango(`view,${n}`);
    }

    function toggleSpecial(name: string): void {
        mango(name ? `toggle_named_scratchpad,${name}` : "toggle_scratchpad");
    }

    function cycleSpecialWorkspace(direction: string): void {
        mango("toggle_scratchpad");
    }

    function monitorNames(): list<string> {
        return monitors.values.map(e => e.name);
    }

    function monitorFor(screen: ShellScreen): var {
        return monitors.values.find(m => m.name === screen?.name) ?? focusedMonitor;
    }

    function trimWsName(name: string): string {
        return name.startsWith("special:") ? name.slice("special:".length) : name;
    }

    function toplevelsForWs(ws: int, ignoredTags = []): var {
        return toplevels.values.filter(t => t.workspace && t.workspace.id === ws && !isToplevelIgnored(t, ignoredTags));
    }

    function isToplevelIgnored(toplevel, ignoredTags = []): bool {
        const ipc = toplevel?.lastIpcObject;
        return !ipc?.class || !ipc.mapped;
    }

    // --------------------------------------------------------------- mango's state, as Hyprland shapes
    property var _monitorsRaw: []
    property var _clientsRaw: []

    function _tagsOf(raw): var {
        // A client's tags: numbers (1-based) or tag objects; use the lowest active one.
        const tags = raw?.tags ?? [];
        const nums = tags.map(t => typeof t === "number" ? t : (t?.is_active || t?.active ? t.index : null)).filter(n => n);
        return nums.length ? Math.min(...nums) : 1;
    }

    function _rebuild(): void {
        const focusedName = (_monitorsRaw.find(m => m.active) ?? _monitorsRaw[0])?.name ?? "";
        const wsById = {};
        const mons = [];

        for (const m of _monitorsRaw) {
            const activeTag = (m.active_tags ?? []).find(t => t > 0) ?? (m.tags ?? []).find(t => t.is_active)?.index ?? 1;
            const mon = {
                name: m.name, id: mons.length, focused: m.name === focusedName,
                x: m.x ?? 0, y: m.y ?? 0, width: m.width ?? 0, height: m.height ?? 0, scale: m.scale ?? 1,
                activeWorkspace: null,
                lastIpcObject: { specialWorkspace: { name: "" }, name: m.name }
            };
            for (const t of m.tags ?? []) {
                const id = t.index ?? 1;
                if (!wsById[id] || mon.focused)
                    wsById[id] = { id, name: String(id), monitor: mon, active: id === activeTag,
                                   focused: mon.focused && id === activeTag,
                                   toplevels: { values: [] }, lastIpcObject: { windows: t.client_count ?? 0, name: String(id) } };
            }
            mon.activeWorkspace = wsById[activeTag] ?? { id: activeTag, name: String(activeTag), monitor: mon, toplevels: { values: [] }, lastIpcObject: { windows: 0 } };
            mons.push(mon);
        }

        const wayland = ToplevelManager.toplevels.values;
        const tops = [];
        for (const c of _clientsRaw) {
            if (c?.id === null || c?.id === undefined)
                continue;
            const tag = _tagsOf(c);
            const ws = wsById[tag] ?? null;
            const t = {
                address: Number(c.id).toString(16), title: c.title ?? "", focused: !!c.is_focused,
                workspace: ws, monitor: mons.find(m => m.name === c.monitor) ?? null,
                wayland: wayland.find(w => w.appId === c.appid && w.title === c.title) ?? null,
                lastIpcObject: {
                    class: c.appid ?? "", initialClass: c.appid ?? "", title: c.title ?? "", initialTitle: c.title ?? "",
                    pid: c.pid ?? 0, at: [c.x ?? 0, c.y ?? 0], size: [c.width ?? 0, c.height ?? 0],
                    floating: !!c.is_floating, fullscreen: c.is_fullscreen ? 2 : 0, pinned: !!c.is_global,
                    xwayland: !!c.is_xwayland, mapped: c.is_visible !== false || !!c.is_minimized,
                    workspace: { id: tag, name: String(tag) }, tags: []
                }
            };
            if (ws)
                ws.toplevels.values.push(t);
            tops.push(t);
        }

        monitors = { values: mons };
        workspaces = { values: Object.values(wsById).sort((a, b) => a.id - b.id) };
        toplevels = { values: tops };
    }

    Process {
        id: watchMonitors
        command: ["mmsg", "watch", "all-monitors"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    if (Array.isArray(d.monitors)) {
                        root._monitorsRaw = d.monitors;
                        const active = d.monitors.find(m => m.active) ?? d.monitors[0];
                        if (active?.keyboardlayout)
                            root.kbLayoutFull = active.keyboardlayout;
                        root._rebuild();
                    }
                } catch (e) {}
            }
        }
        onExited: restartMonitors.start()
    }
    Timer { id: restartMonitors; interval: 1000; onTriggered: watchMonitors.running = true }

    Process {
        id: watchClients
        command: ["mmsg", "watch", "all-clients"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    if (Array.isArray(d.clients)) {
                        root._clientsRaw = d.clients;
                        root._rebuild();
                    }
                } catch (e) {}
            }
        }
        onExited: restartClients.start()
    }
    Timer { id: restartClients; interval: 1000; onTriggered: watchClients.running = true }

    // Wayland toplevels arrive separately; re-match them for window previews.
    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged(): void { root._rebuild(); }
    }

    // Keyboard layout names (as the Hyprland version reads them) -> short codes.
    FileView {
        path: Quickshell.env("CAELESTIA_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch)
                for (const line of layoutMatch[1].split("\n")) {
                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
        }
    }

    IpcHandler {
        function refreshDevices(): void {}
        function cycleSpecialWorkspace(direction: string): void { root.cycleSpecialWorkspace(direction); }
        function listSpecialWorkspaces(): string { return ""; }
        target: "hypr"
    }
}
