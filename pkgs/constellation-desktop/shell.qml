// Constellation's graphical login, run by greetd inside a minimal niri (see niri.kdl and
// /usr/lib/constellation/greeter). Quickshell's greetd service does the talking; Greeter.qml
// is the screen.
//
// Preview without logging in (any password but "wrong" succeeds):
//   CONSTELLATION_GREETER_PREVIEW=1 qs -p /usr/share/constellation/greeter/shell.qml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    readonly property bool preview: Quickshell.env("CONSTELLATION_GREETER_PREVIEW") === "1"
    readonly property string cacheDir: "/var/cache/constellation-greeter"
    readonly property var session: ["niri-session"]

    property var users: []
    property int userIndex: 0
    readonly property var user: users.length > 0 ? users[Math.min(userIndex, users.length - 1)] : ({ name: "", full: "" })
    property string pending: ""          // the password typed, until PAM asks for it
    property bool awaiting: false        // PAM asked a question that the next submit answers
    property bool busy: false
    property string errorText: ""
    property string infoText: ""

    signal failed()

    // ------------------------------------------------------------------ accounts
    FileView { id: passwd; path: "/etc/passwd"; blockLoading: true }
    FileView { id: lastUser; path: root.cacheDir + "/last-user"; blockLoading: true; printErrors: false }

    function loadUsers() {
        if (preview) { users = [{ name: "stephen", full: "Stephen" }]; return; }
        const list = [];
        for (const line of passwd.text().split("\n")) {
            const f = line.split(":");
            if (f.length < 7) continue;
            const uid = parseInt(f[2]);
            if (uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6])) continue;
            list.push({ name: f[0], full: f[4].split(",")[0] });
        }
        users = list;
        const last = (lastUser.text() || "").trim();
        const i = list.findIndex(u => u.name === last);
        userIndex = i >= 0 ? i : 0;
    }
    Component.onCompleted: loadUsers()

    function cycleUser(step) {
        if (busy || users.length < 2) return;
        userIndex = (userIndex + step + users.length) % users.length;
        errorText = ""; infoText = "";
    }

    // ------------------------------------------------------------------ logging in
    function submit(password) {
        if (!user.name) return;
        errorText = "";
        if (preview) { busy = true; previewCheck.password = password; previewCheck.restart(); return; }
        if (awaiting) {                  // answering a second PAM question
            awaiting = false; busy = true;
            Greetd.respond(password);
            return;
        }
        if (busy) return;
        busy = true; infoText = "";
        pending = password;
        Greetd.createSession(user.name);
    }

    function fail(message) {
        if (!preview) Greetd.cancelSession();
        pending = ""; awaiting = false; busy = false;
        errorText = message;
        failed();
    }

    Connections {
        target: Greetd
        enabled: !root.preview
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired && root.pending !== "") {
                Greetd.respond(root.pending);
                root.pending = "";
            } else if (responseRequired) {
                root.awaiting = true; root.busy = false;
                root.infoText = message;
            } else if (error) {
                root.errorText = message;
            } else {
                root.infoText = message;
            }
        }
        function onAuthFailure(message) { root.fail("Неверный пароль · Wrong password"); }
        function onError(error) { root.fail(error); }
        function onReadyToLaunch() { done.running = true; }
    }

    // Tell the wrapper a session is starting (so it does not fall back to the text login),
    // remember who logged in, then hand over to niri-session. Quickshell quits after launch,
    // and niri.kdl quits niri when it does, so greetd can start the session.
    Process {
        id: done
        command: ["sh", "-c", 'touch "${XDG_RUNTIME_DIR:-/tmp}/constellation-greeter-done"']
        onExited: {
            lastUser.setText(root.user.name + "\n");
            Greetd.launch(root.session);
        }
    }

    Timer {
        id: previewCheck
        property string password
        interval: 900
        onTriggered: {
            if (password === "wrong") root.fail("Неверный пароль · Wrong password");
            else { root.busy = false; root.infoText = "Preview: this would log in " + root.user.name; }
        }
    }

    function power(action) {
        if (preview) { infoText = "Preview: systemctl " + action; return; }
        Quickshell.execDetached(["systemctl", action]);
    }

    // ------------------------------------------------------------------ windows
    component GreeterScreen: Greeter {
        id: screenView
        userName: root.user.name
        fullName: root.user.full
        userCount: root.users.length
        busy: root.busy
        errorText: root.errorText
        infoText: root.infoText
        onSubmit: password => root.submit(password)
        onNextUser: root.cycleUser(1)
        onPreviousUser: root.cycleUser(-1)
        onPower: action => root.power(action)
        Connections {
            target: root
            function onFailed() { screenView.shake(); screenView.clearPassword(); }
        }
    }

    // One full-screen layer per monitor; only the first takes the keyboard and shows the card.
    Variants {
        model: root.preview ? [] : Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            readonly property bool primary: modelData === Quickshell.screens[0]
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "#04091c"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "constellation-greeter"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            GreeterScreen { anchors.fill: parent; showCard: panel.primary }
        }
    }

    LazyLoader {
        active: root.preview
        FloatingWindow {
            implicitWidth: 1440
            implicitHeight: 900
            color: "#04091c"
            GreeterScreen { anchors.fill: parent }
        }
    }
}
