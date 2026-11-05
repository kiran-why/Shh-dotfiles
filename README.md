<p align="center"><img src="https://github.com/user-attachments/assets/10fbbe16-89c5-4a7d-8274-27bc7cc6fda3" alt="Shh... dotfiles // quiet // minimal // no useless GUI" width="100%"></p>

<p align="center"><strong>Quiet, minimal Wayland setup for Artix Linux (s6) and Void Linux (runit). No useless GUI.</strong><br>Gentoo and CRUX are on the way.</p>

<div align="center"><h2>• screenshots •</h2></div>

<img width="2560" height="1440" alt="desktop" src="https://github.com/user-attachments/assets/8cbfed6a-b9ad-4028-8a53-2ce614a65485" />

<div align="center"><h2>• overview •</h2></div>

<details>
<summary>What this is / isn't</summary>

- Dotfiles and an installer for Artix Linux (s6) and Void Linux (musl, runit): packages, services, graphics drivers, configs
- No systemd, no elogind: seatd and a PAM module for `XDG_RUNTIME_DIR` instead (pam_rundir, dumb_runtime_dir)
- Terminal first: a GUI only where there is no way around it (web pages, video, images)

</details>

<details>
<summary>Supported distros</summary>

| Distro | Init | Packages | Status |
|---|---|---|---|
| Artix Linux | s6 | pacman + AUR | works |
| Void Linux (musl) | runit | xbps | works |
| Gentoo | OpenRC | Portage | planned |
| CRUX | rc | prt-get | planned |

</details>

<details>
<summary>Installation</summary>

You need a user in the `wheel` group and a working internet connection. Run everything as that user (**not root**).

**Artix:** a fresh base install with s6 (pick `seatd-s6`, not elogind).

```sh
sudo pacman -S git
```

**Void:** a fresh musl base install (`void-installer`).

```sh
sudo xbps-install -Su xbps    # a fresh system must update xbps before anything else
sudo xbps-install -S git
```

Then on both:

```sh
git clone https://github.com/kiran-why/Shh-dotfiles.git ~/Shh-dotfiles
cd ~/Shh-dotfiles
sh install.sh
cd ~ && rm -rf ~/Shh-dotfiles    # optional: all is copied, shh update downloads it again
```

On the first run `install.sh` opens a menu: what to install (screen recording, bluetooth,
firefox, the vpn ...) and a few settings (keyboard layouts, copies or links, yay or paru on Artix).
Reboot and log in on **tty1**: sway starts by itself. Other ttys (`Ctrl+Alt+F2` ...)
stay plain consoles for rescue.

`install.sh` checks the system, updates it (on Artix also adds the Arch `[extra]` repo and `yay` or `paru`), installs
the packages (without the parts you turned off) and the drivers for your graphics card, enables the services,
sets a few system options and copies the configs. It is safe to run again: a file you changed (or one that was there before)
is never deleted, it goes to `name.bak-DATE`, and the list of them is printed at the end.
`sh install.sh --check` only checks that every package exists.

</details>

<details>
<summary>Keybinds</summary>

**`Super + /` shows all keys (searchable).** `Super` is the Windows key. A part turned off in `shh config` takes its keys with it.

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

**Bar:** a red `● rec` while recording (click it to stop), click the time to see the date instead; the button on the far right opens the menu:
wifi, bluetooth, volume, brightness and vpn (the ones turned on in `shh config`).

**zsh:** `Tab` completes, `→` accepts the gray suggestion, `↑` / `↓` search the history by what
you typed, `Ctrl + ←` / `→` jump by words.

</details>

<details>
<summary>Updating</summary>

```sh
shh config    # turn parts on / off, layouts ... (then shh update)
shh update    # install.sh from a fresh clone
shh doctor    # are the services up, files in place, packages installed?
shh color d7263d ff0000    # change a color in every config (the palette: config/foot/foot.ini)
```

Your choices are in `~/.config/shh/config` (`shh config` or by hand), so `shh update` remembers them.
A part turned off loses its keys, scripts and configs, its service is turned off; its packages stay,
`shh update` asks whether to remove them (`pacman -Rs` / `xbps-remove -R`, default no).

`install.sh` also updates the whole system (`pacman -Syu`, `xbps-install -Su`): Artix and Void are rolling,
new packages must not be installed on top of an outdated system.

</details>

<details>
<summary>Uninstalling</summary>

```sh
shh uninstall -n    # show what would be done
shh uninstall       # remove the dotfiles, put your old files (name.bak-DATE) back
```

Packages, services and `/etc` are left alone: it prints what `install.sh` changed
and how to undo it by hand. A config you changed after the install is kept. Removing `seatd` or `pam_rundir` (Void: `dumb_runtime_dir`) breaks the login to sway.

</details>

<details>
<summary>Known issues</summary>

- NVIDIA is untested (no hardware). GTX 6xx / 7xx and older get no NVIDIA driver and run on nouveau
- Black screen after boot on NVIDIA: remove `kms` from `HOOKS` in `/etc/mkinitcpio.conf`, then
  `sudo mkinitcpio -P` (from the Arch wiki)
- Void (musl): no NVIDIA driver (it is built for glibc only), the card runs on nouveau; no VMware clipboard
- Void: `wpa_supplicant` and `iwd` fight over wifi. `install.sh` warns if it is on: turn it off with
  `sudo rm /var/service/wpa_supplicant`, then use the wifi menu
- VirtualBox: sway fails with `Could not initialize EGL` - turn on Settings → Display → Enable 3D Acceleration
  (graphics controller VMSVGA)

</details>

<div align="center"><h2>• thanks •</h2></div>

Ideas taken from [LARBS](https://github.com/LukeSmithxyz/LARBS) (installer) and
[holman/dotfiles](https://github.com/holman/dotfiles) (symlinks).

<div align="center"><h2>• license •</h2></div>

<p>
  <a href="LICENSE">
    <img src="https://github.com/user-attachments/assets/4136c1c7-7715-41d5-b626-38d8cf55305c" alt="MIT License" width="100">
  </a>
</p>

Shh-dotfiles is [Free Software](https://en.wikipedia.org/wiki/Free_software): You can use, study, share and modify it at your will. The dotfiles can be redistributed and/or modified under the terms of the [MIT License](LICENSE).
