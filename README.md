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
<a href="#-installation">📦 Installation</a> •
<a href="#-updating">🔄 Updating</a> •
<a href="#-showcase">📸 Showcase</a> •
<a href="#-keybinds">🎹 Keybinds</a>
</p>

## 📦 Installation

Start from a fresh **Artix base install with s6** (pick `seatd-s6`, not elogind), a user
in the `wheel` group and a working internet connection. Then, as that user (**not root**):


```sh
sudo pacman -S git
git clone https://github.com/kiran-why/Shh-dotfiles.git ~/Shh-dotfiles
cd ~/Shh-dotfiles
sh install.sh
```


Reboot and log in on **tty1**: sway starts by itself. Other ttys (`Ctrl+Alt+F2` ...)
stay plain consoles for rescue.

## 🔄 Updating

To update Shh, you will need to pull the latest changes from GitHub by running the following commands:

```bash
cd ~/Shh-dotfiles
git pull
sh ./install.sh
```

## 📸 Showcase

<img width="1290" height="730" alt="image(2)" src="https://github.com/user-attachments/assets/5c10c6bd-413b-4a90-8860-a3befe76d147" />


## 🎹 Keybinds

`Super` is the Windows key.

| Keys | Action |
|---|---|
| `Super + T` | Terminal (foot) |
| `Super + B` | Browser |
| `Super + F` | Files (broot) |
| `Super + R` | Launcher |
| `Super + Q` | Close Window |
| `Super + Shift + F` | Fullscreen |
| `Super + V` | Float / Tile |
| `Super + Arrows` | Move Focus |
| `Super + Shift + Arrows` | Move Window |
| `Super + Mouse` | Drag (Left) / Resize (Right) a Window |
| `Super + 1 … 0` | Go to Workspace |
| `Super + Shift + 1 … 0` | Send Window to Workspace |
| `Super + S` | Show / Hide Scratchpad |
| `Super + Shift + S` | Send Window to Scratchpad |
| `Super + L` | Leave the Desktop |
| `Print` | Screenshot of a Region, Saved to `~/pictures/screenshots` and Copied |
| `Alt + Shift` | Switch Keyboard Layout (`US` / `RU`) |

## ⚠️ Known issues

- No NVIDIA support (yet)

## 🖇️ Thanks

Ideas taken from [LARBS](https://github.com/LukeSmithxyz/LARBS) (installer) and
[holman/dotfiles](https://github.com/holman/dotfiles) (symlinks).


## 📄 License

<p>
  <a href="https://mit-license.org/">
    <img src="https://github.com/user-attachments/assets/4136c1c7-7715-41d5-b626-38d8cf55305c" alt="MIT License" width="100">
  </a>
</p>


Shh-dotfiles is [Free Software](https://en.wikipedia.org/wiki/Free_software): You can use, study, share and modify it at your will. The app can be redistributed and/or modified under the terms of the [MIT License](https://mit-license.org/).

<div align="right">
<table><td>
<a href="#start-of-content">↥ Scroll to top</a>
</td></table>
</div>
