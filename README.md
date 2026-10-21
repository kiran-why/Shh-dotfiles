```
   _____ __    __
  / ___// /_  / /_               __     __  ____ __
  \__ \/ __ \/ __ \          ___/ /__  / /_/ _(_) /__ ___
 ___/ / / / / / / / _ _ _   / _  / _ \/ __/ _/ / / -_|_-<
/____/_/ /_/_/ /_/ (_|_|_)  \_,_/\___/\__/_//_/_/\__/___/

      // quiet  // minimal  // no useless GUI
```

> **🚧 Work in progress.** The installer already sets up a fresh system from start to
> finish, but most configs are still being written. So far everything has been tested
> only in a VirtualBox VM. Expect rough edges.

Dotfiles and an installer for **Artix Linux with the s6 init system**

## Stack

| | |
|---|---|
| distro / init | Artix Linux, s6 (no systemd) |
| login | plain TTY, no display manager; the desktop starts from `~/.zprofile` on tty1 |
| seat | seatd (no elogind) |
| desktop | your choice at install time, see below |
| shell / terminal / editor | zsh / foot / neovim |
| launcher | foot + fzf (own script) |
| files | nnn |
| notifications | mako |
| sound | PipeWire + WirePlumber, mixer ncpamixer |
| network | iwd (built-in DHCP) + openresolv |
| AUR | yay |
| font | JetBrains Mono Nerd Font |

## Desktops

The installer asks which desktop you want:

```
:: which desktop do you prefer?
  1) sway      - tiling windows and workspaces, swaybar
  2) hyprland  - tiling with animations and effects, waybar
  3) niri      - scrolling tiling: windows in an endless row, waybar
```

| desktop | status |
|---|---|
| **hyprland** + waybar | main focus right now. |
| **sway** + swaybar | first config; paused for now |
| **niri** + waybar | no config yet |

You can skip the question with `--wm sway`, `--wm hyprland` or `--wm niri`.

## Install

Start from a fresh **Artix base install with s6**, a normal user in the `wheel`
group (sudo) and a working internet connection. Then, as that user (**not root**):

```sh
sudo pacman -S git
git clone https://github.com/kiran-why/Shh-dotfiles.git ~/Shh-dotfiles
cd ~/Shh-dotfiles
sh install.sh
```

Reboot and log in on **tty1**: the chosen desktop starts by itself.
Other ttys (`Ctrl+Alt+F2` ...) stay plain consoles, handy if something breaks.

Other options:

```sh
sh install.sh --check          # only check that every package exists, install nothing
sh install.sh --wm hyprland    # don't ask, use this desktop
sh install.sh --help
```

Running `install.sh` again is safe: whatever is already done is skipped.

### What `install.sh` does

1. asks which desktop to install
2. checks the system: Artix, s6, sudo, internet, not root
3. allows passwordless sudo **only while it runs** (removed on exit, even on Ctrl+C)
4. pacman tweaks: colours, parallel downloads, `makepkg` on all cores
5. enables the Arch `[extra]` repo through `artix-archlinux-support`
6. installs `yay`
7. installs packages from `packages/common.csv` + `packages/<desktop>.csv`
8. enables s6 services from `services.txt` (seatd, dbus, iwd)
9. system settings: zsh as login shell, iwd config, no PC speaker beep
10. links the configs into `$HOME` with `link.sh`

Nothing is ever deleted: a file that is in the way is renamed to `name.bak-DATE`.

## Repository layout

```
install.sh          the installer
link.sh             symlinks configs into $HOME   (link.sh --dry-run to preview)
lib.sh              shared messages, colours and the logo
services.txt        s6 services to enable
packages/           package lists: tag,package,description  (empty tag = pacman, A = AUR)
home/       ->  ~/                .zprofile ...
config/     ->  ~/.config/        configs shared by every desktop
scripts/    ->  ~/.local/bin/     everyday commands (launcher ...)
desktops/   ->  ~/.config/        configs of one desktop: hyprland/config/{hypr,waybar}
```

Everything is plain POSIX `sh`, no bash-isms.

## Hyprland keys

`Super` is the Windows key.

| keys | action |
|---|---|
| `Super + Q` | terminal (foot) |
| `Super + R` | launcher |
| `Super + E` | files (nnn) |
| `Super + C` | close window |
| `Super + F` | fullscreen |
| `Super + V` | float / tile |
| `Super + arrows` | move focus |
| `Super + Shift + arrows` | move window |
| `Super + 1 … 0` | go to workspace |
| `Super + Shift + 1 … 0` | send window to workspace |
| `Super + S` | scratchpad |
| `Super + M` | leave Hyprland |
| `Alt + Shift` | switch keyboard layout (us / ru) |

## Known issues / not done yet

- `desktops/` is not linked by `link.sh` yet: copy `desktops/hyprland/config/*` to `~/.config/` by hand
- PipeWire is not started yet, so there is no sound and no sound module on the bar
- no NVIDIA support (yet)
- still to do: foot and zsh configs, notifications, screenshots.

## Thanks

Ideas taken from [LARBS](https://github.com/LukeSmithxyz/LARBS) (installer),
[holman/dotfiles](https://github.com/holman/dotfiles) (symlinks) and
[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (Hyprland config layout).
