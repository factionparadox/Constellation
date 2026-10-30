# Desktop

Hyperon, Constellation's respin of Hyprland, frozen at Hyprland 0.56.2: the last release that reads the classic `hyprland.conf` format (0.57 dropped it for Lua). Windows open side by side in columns you scroll along, as on niri (Hyprland's built-in scrolling layout, on every workstation). `pkgs/hyperon` builds Hyprland and its own libraries at the revisions 0.56.2 was released with and installs those libraries privately in `/usr/lib/hyperon`, so Arch's updates to its Hyprland packages never reach it. Its name, defaults and config paths are Hyperon's (`pkgs/hyperon/hyperon-brand` lists every change); programs that talk to Hyprland still work, because the IPC socket, `hyprctl` and the `HYPRLAND_*` variables are unchanged.

The Caelestia shell draws the bar, launcher, dashboard, notifications, lock screen and power menu. Caelestia is written for Hyprland, so `pkgs/caelestia-shell` builds a reviewed upstream commit unmodified. Login is greetd with Constellation's own login screen, which also runs on Hyperon. Configuration: `/etc/xdg/hyperon/hyperon.conf` (copy it to `~/.config/hyperon/hyperon.conf` to change it) and `~/.config/caelestia/shell.json`. `hyperonctl` is `hyprctl` under Hyperon's name.

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
