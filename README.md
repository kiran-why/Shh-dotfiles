<p id="start-of-content"> </p>

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

<p align="center"><strong>Quiet, minimal Wayland setup for Artix Linux (s6). No useless GUI.</strong></p>

<p align="center">
<a href="#stack">Stack</a> •
<a href="#installation">Installation</a> •
<a href="#updating">Updating</a> •
<a href="#uninstalling">Uninstalling</a> •
<a href="#layout">Layout</a> •
<a href="#showcase">Showcase</a> •
<a href="#keybinds">Keybinds</a> •
<a href="#known-issues">Known issues</a>
</p>

## Stack

| | |
|---|---|
| Distro / Init | Artix Linux, s6 (no systemd) |
| Login | Plain TTY, no display manager; sway starts on tty1 |
| Seat | seatd + pam_rundir (no elogind) |
| Desktop | sway + swaybar, no XWayland (can be turned on in `shh config` for X11 programs) |
| Shell / Terminal / Editor | zsh / foot / neovim |
| Launcher, Menus | foot + fzf (own scripts) |
| Files | broot |
| Images / Video / PDF | imv / mpv / firefox |
| Notifications | mako |
| Clipboard | wl-clipboard + cliphist (history on `Super + C`) |
| Sound | PipeWire + WirePlumber |
| Network | iwd (wifi), dhcpcd (wired), openresolv |
| Bluetooth | bluez (bluetoothctl), own menu |
| AUR helper | yay or paru (`shh config`) |
| Browser | firefox |
| VPN | sing-box with its own menu (`vpn`) |
| Font | JetBrains Mono Nerd Font |

## Installation

Start from a fresh **Artix base install with s6** (pick `seatd-s6`, not elogind), a user
in the `wheel` group and a working internet connection. Then, as that user (**not root**):


```sh
sudo pacman -S git
git clone https://github.com/kiran-why/Shh-dotfiles.git ~/Shh-dotfiles
cd ~/Shh-dotfiles
sh install.sh
cd ~ && rm -rf ~/Shh-dotfiles    # optional: all is copied, shh update downloads it again
```


On the first run `install.sh` opens a menu: what to install (screen recording, bluetooth,
the browser, the vpn ...) and a few settings (keyboard layouts, yay or paru, copies or links).
Reboot and log in on **tty1**: sway starts by itself. Other ttys (`Ctrl+Alt+F2` ...)
stay plain consoles for rescue.

<details>
<summary>What install.sh does</summary>

`install.sh` checks the system, asks what to install (`shh config`, only on the first run),
adds the Arch `[extra]` repo and `yay` or `paru`, installs
`packages/common.csv` (without the parts you turned off) and the drivers for your graphics card, enables the s6 services from `services.txt`, sets a few system
options and copies the configs with `link.sh`. It is safe to run again: a file you changed (or one that was there before)
is never deleted, it goes to `name.bak-DATE`, and the list of them is printed at the end.
`sh install.sh --check` only checks that every package exists.

</details>

## Updating

```sh
shh config    # turn parts on / off, layouts, yay or paru (then shh update)
shh update    # install.sh from a fresh clone
shh doctor    # are the services up, files in place, packages installed?
shh color d7263d ff0000    # change a color in every config (the palette: config/foot/foot.ini)
```

<details>
<summary>Turning a part off later</summary>

Your choices are in `~/.config/shh/config` (`shh config` or by hand), so `shh update` remembers them.
A part turned off loses its keys, scripts and configs, its service is turned off; its packages stay,
`shh update` prints the `pacman -Rs` line to remove them.

</details>

<details>
<summary>Why it updates the whole system</summary>

`install.sh` also updates the whole system (`pacman -Syu`): on Arch-based systems new packages
must not be installed on top of an outdated system.

</details>

## Uninstalling

```sh
shh uninstall -n    # show what would be done
shh uninstall       # remove the dotfiles, put your old files (name.bak-DATE) back
```

<details>
<summary>What stays</summary>

Packages, services and `/etc` are left alone: `link.sh` prints what `install.sh` changed
and how to undo it by hand. A config you changed after the install is kept. Removing `seatd` or `pam_rundir` breaks the login to sway.

</details>

## Layout

```
install.sh link.sh lib.sh   installer, copies the files, shared messages
packages/common.csv         packages: tag,package,description (empty tag = pacman, A = AUR)
packages/CARD.csv           graphics drivers: amd, intel, nvidia, nvidia-580xx
services.txt                s6 services
components.txt              the parts shh config can turn off: packages, files, services
config/     ->  ~/.config/     sway (features/: one file per part), swaybar, foot, fzf (the look of all menus), fastfetch, broot, nvim, mako, cliphist, imv, mimeapps.list
home/       ->  ~/             .zprofile .zshrc
scripts/    ->  ~/.local/bin/  shh, launcher, keys, clipboard, volume, wifi, bluetooth, vpn, sound, wallpaper, screenshot, record, autotile, screen, hardware
wallpapers/ ->  ~/wallpapers/  the newest picture here is the wallpaper
lib.sh link.sh services.txt components.txt packages/  ->  ~/.local/share/shh/  for shh
```

<details>
<summary>Copies or links (for working on the dotfiles)</summary>

What was installed is listed in `~/.local/state/shh/installed`.
To work on the dotfiles, keep the repo and run `sh link.sh --link`: the files in `$HOME`
become links to the repo, so an edit lands right in it, and `shh update` does a `git pull`.
**Do not delete the repo then**: every link, `shh` too, points into it.
`sh link.sh --copy` goes back to copies.

</details>

## Showcase

<img width="1290" height="730" alt="image(2)" src="https://github.com/user-attachments/assets/5c10c6bd-413b-4a90-8860-a3befe76d147" />


## Keybinds

`Super` is the Windows key.

| Keys | Action |
|---|---|
| `Super + T` | Terminal |
| `Super + R` | Launcher |
| `Super + B` | Browser |
| `Super + F` | Files |
| `Super + Q` | Close Window |
| `Super + Arrows` | Move Focus |
| `Super + 1 … 0` | Go to Workspace |
| `Super + Shift + 1 … 0` | Send Window to Workspace |
| `Super + L` | Leave the Desktop |
| `Print` | Screenshot of a Region |

**`Super + /` shows all keys (searchable).**

**Bar:** a red `● rec` while recording (click it to stop), click wifi for the network menu, bluetooth (shown only with an adapter) for the bluetooth menu,
the volume for the sound menu, scroll on it to change it.

**zsh:** `Tab` completes, `→` accepts the gray suggestion, `↑` / `↓` search the history by what
you typed, `Ctrl + ←` / `→` jump by words.

## Known issues

- NVIDIA is untested (no hardware). GTX 6xx / 7xx and older get no NVIDIA driver and run on nouveau
- Black screen after boot on NVIDIA: remove `kms` from `HOOKS` in `/etc/mkinitcpio.conf`, then
  `sudo mkinitcpio -P` (from the Arch wiki)

## Thanks

Ideas taken from [LARBS](https://github.com/LukeSmithxyz/LARBS) (installer) and
[holman/dotfiles](https://github.com/holman/dotfiles) (symlinks).


## License

<p>
  <a href="LICENSE">
    <img src="https://github.com/user-attachments/assets/4136c1c7-7715-41d5-b626-38d8cf55305c" alt="MIT License" width="100">
  </a>
</p>


Shh-dotfiles is [Free Software](https://en.wikipedia.org/wiki/Free_software): You can use, study, share and modify it at your will. The dotfiles can be redistributed and/or modified under the terms of the [MIT License](LICENSE).

<div align="right">
<table><td>
<a href="#start-of-content">↥ Scroll to top</a>
</td></table>
</div>
