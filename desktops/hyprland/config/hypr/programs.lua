-- ~/.config/hypr/programs.lua - which program opens for what
-- loaded by keybinds.lua with  local programs = require("programs")

local home = os.getenv("HOME")

return {
    terminal    = "foot",
    browser     = "firefox",
    -- nnn is a terminal program, so it opens inside foot
    fileManager = "foot nnn",
    -- our launcher: foot + fzf in a floating window (see rules.lua)
    menu        = "foot --app-id=launcher " .. home .. "/.local/bin/launcher",
    -- region screenshot: saved and copied (scripts/screenshot)
    screenshot  = home .. "/.local/bin/screenshot",
}
