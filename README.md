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

A quiet sway desktop with no systemd. Terminal first: a GUI only where there is no way around it.

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

<div align="center">
  <h2>• documentation •</h2>
  <p>Everything else is on the site</p>
  <h3><a href="https://shhware.org">shhware.org</a></h3>
  <p>
    <a href="https://shhware.org/en/projects/shh-dotfiles/keybinds.html">Keybinds</a> ·
    <a href="https://shhware.org/en/projects/shh-dotfiles/shh.html">Shh commands</a> ·
    <a href="https://shhware.org/en/projects/shh-dotfiles/components.html">Components</a> ·
    <a href="https://shhware.org/en/projects/shh-dotfiles/known-issues.html">Known issues</a>
  </p>
</div>
