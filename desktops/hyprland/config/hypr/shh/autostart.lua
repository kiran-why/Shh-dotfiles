-- shh/autostart.lua - programs started once, when hyprland starts

hl.on("hyprland.start", function()
    -- the bar; its own config will be in ~/.config/waybar
    hl.exec_cmd("waybar")
end)
