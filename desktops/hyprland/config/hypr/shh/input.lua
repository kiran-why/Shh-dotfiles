-- shh/input.lua - keyboard and mouse

hl.config({
    input = {
        -- english + russian, switch with Alt+Shift
        kb_layout  = "us,ru",
        -- VERIFY: kb_options is not used in the configs we studied,
        -- the name is taken from the old hyprland.conf format
        kb_options = "grp:alt_shift_toggle",

        -- focus follows the mouse pointer
        follow_mouse = 1,
    },
})
