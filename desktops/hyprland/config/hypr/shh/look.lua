-- shh/look.lua - borders, gaps, opacity, animations
-- black and white, no gaps; the focused window is solid, the rest see-through

local colors = require("shh.colors")

hl.config({
    general = {
        -- no gaps: windows touch each other and the screen edges
        gaps_in  = 0,
        gaps_out = 0,

        border_size = 2,

        -- same black border for every window; focus is shown by opacity
        col = {
            active_border   = colors.black,
            inactive_border = colors.black,
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        -- only a slight rounding
        rounding       = 3,
        rounding_power = 2,

        -- the focused window is solid, all others are see-through
        active_opacity   = 1.0,
        inactive_opacity = 0.85,

        shadow = { enabled = false },
        blur   = { enabled = false },
    },

    -- built-in animations for now, tuning comes later
    animations = {
        enabled = true,
    },

    misc = {
        -- plain black background instead of the hyprland wallpaper and logo;
        -- the ascii art wallpaper comes later
        background_color         = colors.black,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
})
