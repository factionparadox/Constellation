# Desktop

niri, a scrolling tiling compositor: windows open side by side in an endless strip and you scroll along it, instead of being squeezed into the screen. The Caelestia shell (its niri port by Cantfirmed, pinned in `pkgs/niri-caelestia-shell`) draws the bar, launcher, dashboard, notifications, lock screen and power menu. Login is greetd with tuigreet. Configuration: `/etc/niri/config.kdl` (copy it to `~/.config/niri/` to change it) and `~/.config/caelestia/shell.json`.

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
