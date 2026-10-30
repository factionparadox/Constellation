# Desktop

Hyperon, Constellation's Wayland compositor, with a classic config file and no Lua. Windows open side by side in columns you scroll along, as on niri (the scrolling layout, on every workstation). It is built from the BSD-licensed Hyprland 0.56.2 sources, frozen there, with its libraries installed privately in `/usr/lib/hyperon` so Arch's updates never reach them; `pkgs/hyperon/hyperon-brand` lists every change. Programs written for Hyprland's interfaces still work: the IPC socket, `hyprctl` and the `HYPRLAND_*` variables are kept.

The Caelestia shell draws the bar, launcher, dashboard, notifications, lock screen and power menu. Hyperon speaks the interfaces Caelestia is written for, so `pkgs/caelestia-shell` builds a reviewed upstream commit unmodified. Login is greetd with Constellation's own login screen, which also runs on Hyperon. Configuration: `/etc/xdg/hyperon/hyperon.conf` (copy it to `~/.config/hyperon/hyperon.conf` to change it) and `~/.config/caelestia/shell.json`. `hyperonctl` is `hyprctl` under Hyperon's name.

| Keys | Action |
| --- | --- |
| **Workstations** | |
| Super+1 … Super+9 | switch to workstation 1–9 |
| Super+Shift+1 … Super+Shift+9 | move the focused window to workstation 1–9 |
| Super+Tab | fit every column of the workstation on screen |
| **Applications** | |
| Super+W | Firefox |
| Super+T | kitty |
| Super+D | Discord |
| Super+V | VLC |
| Super+E | file manager (Dolphin) |
| Super+Space | Caelestia launcher |
| Super+A | ani-cli |
| Super+P | Proton VPN |
| Super+Alt+R | today's Russian words |
| **Windows** | |
| Super+Q | close the focused window |
| Super+F | maximise the focused window |
| Super+R | cycle the column width: 33% → 50% → 67% → 100% |
| Super+Shift+Space | toggle floating / tiled |
| Super+left drag / Super+right drag | move / resize a window |
| Super+arrows, Super+Shift+arrows | move focus / move columns along the strip (windows up and down) |
| Super+Shift+F | full screen |
| **Caelestia shell** | |
| Super+Shift+D | dashboard |
| Super+N / Super+Shift+N | utilities / notifications |
| Super+Shift+V | clipboard history |
| Super+Shift+W | pick a wallpaper |
| Super+Escape | power menu |
| **Session** | |
| Super+X | lock |
| Super+Z | suspend (locks first) |
| **Screenshots** | |
| Super+Shift+S | capture a region (grim, slurp, swappy) |
| **Keyboard and media** | |
| Alt+Shift | switch keyboard layout (English gb / Russian) |
| Volume, mute, mic mute, brightness keys | as labelled |

The wallpaper is in `/usr/share/backgrounds/constellation`; Super+Shift+W picks another from that folder.
