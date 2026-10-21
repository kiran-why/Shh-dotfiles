-- ~/.config/hypr/workspaces.lua - workspace keys (the same as in sway and niri)

local mainMod = "SUPER"

-- mainMod + 1..0 to switch, mainMod + SHIFT + 1..0 to send the window there
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- scratchpad: mainMod + S shows / hides it, mainMod + SHIFT + S puts the window there
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
