-- ~/.config/hypr/hyprland.lua - Shh... dotfiles
--
-- this file only loads the others, one topic per file, from the shh/ folder.
-- require("shh.look") runs ~/.config/hypr/shh/look.lua (the dot is a "/")
-- layout taken from end-4/dots-hyprland, simplified

require("shh.input")
require("shh.look")
require("shh.rules")
require("shh.keybinds")
require("shh.workspaces")
require("shh.autostart")
