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

A quiet sway desktop with no systemd. Terminal first: a GUI only where there is no way around it.

**Supported distributions:** Artix Linux (s6), Void Linux (musl, runit), and KISS Linux Community (runit).

<div align="center"><h2>• installation •</h2></div>

Start from a base installation with internet access and Git installed.
Run the commands as your **regular user, not root**. Your user must be in the `wheel` group and able to run commands with `sudo`.

```sh
git clone https://github.com/kiran-why/Shh-dotfiles.git
cd Shh-dotfiles
sh install.sh
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
