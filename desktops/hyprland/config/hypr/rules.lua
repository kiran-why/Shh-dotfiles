-- ~/.config/hypr/rules.lua - rules for particular windows

-- the launcher floats in the middle instead of taking a tile
hl.window_rule({ match = { class = "^(launcher)$" }, float  = true })
hl.window_rule({ match = { class = "^(launcher)$" }, center = true })
hl.window_rule({ match = { class = "^(launcher)$" }, size   = { "600", "400" } })
