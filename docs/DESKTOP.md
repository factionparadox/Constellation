# Desktop

MangoWM, a scrolling compositor with a Hyprland-style feel: windows open side by side in columns you scroll along (the scroller layout on every workstation). The Caelestia shell draws the bar, launcher, dashboard, notifications, lock screen and power menu. Upstream Caelestia is written for Hyprland; `pkgs/caelestia-mango` builds a reviewed upstream commit with its Hyprland service replaced by a Mango one (`Hypr.qml`, which follows Mango through `mmsg`), so Caelestia's own updates carry over. Login is greetd with Constellation's own login screen, which also runs on Mango. Configuration: `/etc/mango/config.conf` (copy it to `~/.config/mango/config.conf` to change it) and `~/.config/caelestia/shell.json`.

On Mango, Hyprland's special workspaces become Mango's scratchpads, and the caps-lock and num-lock indicators are not shown (Mango does not report them).

| Keys | Action |
| --- | --- |
| **Workstations** | |
| Super+1 … Super+9 | switch to workstation 1–9 |
| Super+Shift+1 … Super+Shift+9 | move the focused window to workstation 1–9 |
| Super+Tab | workstation and window overview |
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
| Super+F | maximise the current column |
| Super+R | cycle the column width: 33% → 50% → 67% → 100% |
| Super+Shift+Space | toggle floating / tiled |
| Super+left drag / Super+right drag | move / resize a window |
| Super+arrows, Super+Shift+arrows | move focus / move windows along the strip |
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
| Super+Shift+/ | show every key binding on screen |

The wallpaper is in `/usr/share/backgrounds/constellation`; Super+Shift+W picks another from that folder.
