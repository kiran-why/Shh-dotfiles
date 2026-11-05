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

Dotfiles and an installer for Artix Linux (s6) and Void Linux (musl, runit). Gentoo and CRUX are on the way.

<div align="center"><h2>• overview •</h2></div>

- No systemd
- Terminal first: a GUI only where there is no way around it

<div align="center"><h2>• installation •</h2></div>

You need a user in the `wheel` group (run everything as that user, **not root**) and internet.

**Artix:** a fresh base install with s6 (pick `seatd-s6`).

```sh
sudo pacman -S git
```

**Void:** a fresh musl base install.

```sh
sudo xbps-install -Su xbps    # a fresh system must update xbps first
sudo xbps-install -S git
```

**Then on both:**

```sh
git clone https://github.com/kiran-why/Shh-dotfiles.git ~/Shh-dotfiles
cd ~/Shh-dotfiles
sh install.sh
cd ~ && rm -rf ~/Shh-dotfiles    # optional: shh update downloads it again
```

Reboot and log in on tty1: sway starts by itself.

<div align="center"><h2>• keybinds •</h2></div>

**`Super + /` shows all keys (searchable).** `Super` is the Windows key.

| Keys | Action |
|---|---|
| `Super + T` | Terminal |
| `Super + R` | Launcher |
| `Super + M` | Menu: Wifi, Volume, Bluetooth, VPN, Light |
| `Super + B` | Browser |
| `Super + F` | Files |
| `Super + Q` | Close Window |
| `Super + Arrows` | Move Focus |
| `Super + 1 … 0` | Go to Workspace |
| `Super + Shift + 1 … 0` | Send Window to Workspace |
| `Super + L` | Leave the Desktop |
| `Print` | Screenshot of a Region |

Bar: click `● rec` to stop recording, the time to see the date, the button on the far right for the menu.

<div align="center"><h2>• updating •</h2></div>

```sh
shh config                 # turn parts on / off, settings (then shh update)
shh update                 # update the system and the dotfiles
shh doctor                 # services up, files in place, packages installed?
shh color d7263d ff0000    # change a color in every config
```

<div align="center"><h2>• uninstalling •</h2></div>

```sh
shh uninstall -n    # show what would be done
shh uninstall       # remove the dotfiles, put your old files (name.bak-DATE) back
```

<div align="center"><h2>• known issues •</h2></div>

- NVIDIA is untested; GTX 6xx / 7xx and older run on nouveau
- NVIDIA, black screen after boot: remove `kms` from `HOOKS` in `/etc/mkinitcpio.conf`, then `sudo mkinitcpio -P`
- Void (musl): no NVIDIA driver (nouveau only)
- Void: `wpa_supplicant` fights `iwd` over wifi, turn it off: `sudo rm /var/service/wpa_supplicant`

<div align="center"><h2>• thanks •</h2></div>

Ideas taken from [LARBS](https://github.com/LukeSmithxyz/LARBS) (installer) and
[holman/dotfiles](https://github.com/holman/dotfiles) (symlinks).

<div align="center"><h2>• license •</h2></div>

Free Software under the [MIT License](LICENSE).
