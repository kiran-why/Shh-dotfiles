```
         █▄        █▄                  ▄█▀          ▄█▀    ▄█▀█▄ ▄▀▀▄  ▄█▀
         █▓▌       █▓▌                ▐▓█▄         ▐▓█▄▄  █▓▌  █▌▌■▀▐▌▐▓█
   ▄▄██▄▐▓▓█░▄▓▄  ▐▓▓█░▄▓▄        ▄▓▄░▀▓▓▌  ▄▓██▄  ▀▓▓▌  ▐▓▓▄  ▀ ▀■▓▀ ▐▓▓▌      ▄▄█▄▄    ▄▄██▄
  ▓▓  ▀▀▐▒▒ ▀ ▀██ ▐▒▒ ▀ ▀██      ██▀ ▀ ▒▒  ▓▓▀  ▀▓ ▐▒▒    ▒▒▌▀█▄  ▄▄▓▀▐▒▒      ▓█▀ ▀▓▓  ▓▓  ▀▀
   ▀▀▀▄  ░░▌   ▐▓▌ ░░▌   ▐▓▌    ▐▓▌    ░░▌▐▒▌   ▐▓▌ ░░▌  ▐░░  ░   ▐▓▓  ░░▌    ▐▒▌  ▄▒▀   ▀▀▀▄
▐█▌  ░█░ ██▓  ▄██  ██▓  ▄██      ██▄  ▐██ ▐░░▄ ▄▒▒  ▐██  ██▌       ▒▒▌ ▐██   ▄ ▀░░▀   ▐█▌  ░█░
 █░▄██▀  ▐█▌  █▀   ▐█▌  █▀        ▀░█▄██▌  ▀█░█░▀    █░▀▀░█       ▐░░   █░█▄█▀  ▀█▄  ▄ █░▄██▀
  ▀▀░     ▀    ▀    ▀    ▀           ▀▀▀      ▀     ▀      ▀      ██▀    ▀▀▀       ▀▀   ▀▀░
                                                                  ▀▄

                           // quiet  // minimal  // no useless GUI
```

> **🚧 Work in progress.** The installer already sets up a fresh system from start to
> finish, but most configs are still being written. So far everything has been tested

Dotfiles and an installer for **Artix Linux with the s6 init system**

## Stack

| | |
|---|---|
| distro / init | Artix Linux, s6 (no systemd) |
| login | plain TTY, no display manager; the desktop starts from `~/.zprofile` on tty1 |
| seat | seatd (no elogind) |
| desktop | sway + swaybar, no XWayland |
| shell / terminal / editor | zsh / foot / neovim |
| launcher | foot + fzf (own script) |
| files | broot (a tree) |
| notifications | mako |
| sound | PipeWire + WirePlumber, own menu on the bar, mixer ncpamixer |
| network | iwd (built-in DHCP) + openresolv |
| AUR | yay |
| font | JetBrains Mono Nerd Font |

## Install

Start from a fresh **Artix base install with s6**, a normal user in the `wheel`
group (sudo) and a working internet connection. Then, as that user (**not root**):

```sh
sudo pacman -S git
git clone https://github.com/kiran-why/Shh-dotfiles.git ~/Shh-dotfiles
cd ~/Shh-dotfiles
sh install.sh
```

Reboot and log in on **tty1**: sway starts by itself.
Other ttys (`Ctrl+Alt+F2` ...) stay plain consoles, handy if something breaks.

Other options:

```sh
sh install.sh --check    # only check that every package exists, install nothing
sh install.sh --help
```

Running `install.sh` again is safe: whatever is already done is skipped.

### What `install.sh` does

1. checks the system: Artix, s6, sudo, internet, not root
2. allows passwordless sudo **only while it runs** (removed on exit, even on Ctrl+C)
3. pacman tweaks: colours, parallel downloads, `makepkg` on all cores
4. enables the Arch `[extra]` repo through `artix-archlinux-support`
5. installs `yay`
6. installs packages from `packages/common.csv`
7. enables s6 services from `services.txt` (seatd, dbus, iwd)
8. system settings: zsh as login shell, iwd config, no PC speaker beep
9. links the configs into `$HOME` with `link.sh`

Nothing is ever deleted: a file that is in the way is renamed to `name.bak-DATE`.

## Repository layout

```
install.sh          the installer
link.sh             symlinks configs into $HOME   (link.sh --dry-run to preview)
lib.sh              shared messages, colours and the logo
services.txt        s6 services to enable
packages/           package list: tag,package,description  (empty tag = pacman, A = AUR)
home/       ->  ~/                .zprofile .zshrc
config/     ->  ~/.config/        sway, swaybar, foot, fastfetch, broot, nvim, mako
scripts/    ->  ~/.local/bin/     everyday commands (launcher, wallpaper, screenshot, autotile, sound, volume)
wallpapers/ ->  ~/wallpapers      the newest picture here is the wallpaper (pictures are not in git)
```

Everything is plain POSIX `sh`, no bash-isms.

## Keys

`Super` is the Windows key.

| keys | action |
|---|---|
| `Super + T` | terminal (foot) |
| `Super + B` | browser |
| `Super + F` | files (broot) |
| `Super + R` | launcher |
| `Super + Q` | close window |
| `Super + Shift + F` | fullscreen |
| `Super + V` | float / tile |
| `Super + arrows` | move focus |
| `Super + Shift + arrows` | move window |
| `Super + mouse` | drag (left) / resize (right) a window |
| `Super + 1 … 0` | go to workspace |
| `Super + Shift + 1 … 0` | send window to workspace |
| `Super + S` | show / hide scratchpad |
| `Super + Shift + S` | send window to scratchpad |
| `Super + L` | leave the desktop |
| `Print` | screenshot of a region: saved to `~/pictures/screenshots` and copied |
| `Alt + Shift` | switch keyboard layout (us / ru) |

On the bar: click the wifi icon for `iwctl`, click the volume for a sound menu
(louder, quieter, mute, output device, mic), scroll on it to change the volume.

In the terminal (zsh):

| keys | action |
|---|---|
| `Tab` | complete a command, path or flag; again for a list |
| `→` / `End` | accept the gray suggestion from the history |
| `↑` / `↓` | older / newer commands that start like the typed text |
| `Ctrl + ←` / `Ctrl + →` | one word back / forward |

## Known issues / not done yet

- no NVIDIA support (yet)

## Thanks

Ideas taken from [LARBS](https://github.com/LukeSmithxyz/LARBS) (installer) and
[holman/dotfiles](https://github.com/holman/dotfiles) (symlinks).
