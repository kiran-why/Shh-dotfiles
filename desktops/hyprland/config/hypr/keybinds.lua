-- ~/.config/hypr/keybinds.lua - keys for programs and windows
-- the same keys as in sway and niri; workspace keys live in workspaces.lua

local programs = require("programs")

-- the Windows key
local mainMod = "SUPER"

-- programs
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(programs.browser))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(programs.fileManager))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(programs.menu))

-- windows
hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))

-- leave hyprland (hyprshutdown if installed, otherwise a plain exit)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- screenshot of a region: saved and copied (scripts/screenshot)
hl.bind("Print", hl.dsp.exec_cmd(programs.screenshot))

-- focus with mainMod + arrows, move the window with mainMod + SHIFT + arrows
local arrows = { "left", "right", "up", "down" }
for _, dir in ipairs(arrows) do
    hl.bind(mainMod .. " + " .. dir,         hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

-- drag a window with mainMod + left mouse, resize it with mainMod + right mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- volume keys (laptop). VERIFY: needs pipewire running, not started yet
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
