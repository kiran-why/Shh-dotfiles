-- ~/.config/nvim/init.lua - for now only the look: black and white, red for errors
-- base is the built-in "quiet" colorscheme; its few colors are made gray below

vim.o.termguicolors = true
vim.o.background = "dark"
vim.cmd.colorscheme("quiet")

-- the palette (same as foot.ini); change a color here
local black = "#000000"
local dark = "#2a2a2a"
local gray = "#5a5a5a"
local light = "#a0a0a0"
local white = "#e6e6e6"
local bright = "#ffffff"
local red = "#d7263d"

-- hl(group, colors): fg = text, bg = background (:help nvim_set_hl)
local function hl(group, colors)
    vim.api.nvim_set_hl(0, group, colors)
end

-- text on pure black, like the terminal
hl("Normal", { fg = white, bg = black })

-- the current line is dark gray; the selection is lighter, so it still
-- shows up on the current line
hl("CursorLine", { bg = dark })
hl("CursorLineNr", { fg = white, bg = dark })

-- selection and search: grays instead of orange / blue / pink
hl("Visual", { fg = bright, bg = gray })
hl("Search", { fg = black, bg = light })
hl("IncSearch", { fg = black, bg = bright })
hl("CurSearch", { fg = black, bg = bright })
hl("WildMenu", { fg = black, bg = bright, bold = true })
hl("MatchParen", { fg = bright, bold = true, underline = true })
hl("QuickFixLine", { bg = dark })
hl("CursorIM", { fg = black, bg = bright })
hl("Todo", { fg = bright, bold = true })

-- completion menu: matches in white bold, not pink
hl("PmenuMatch", { fg = black, bg = light, bold = true })
hl("PmenuMatchSel", { fg = black, bg = white, bold = true })

-- diffs: added / changed in grays, deleted in red
hl("DiffAdd", { fg = bright, bg = dark })
hl("DiffChange", { bg = dark })
hl("DiffText", { fg = black, bg = light })
hl("DiffDelete", { fg = red })

-- spelling: only real mistakes are red
hl("SpellBad", { sp = red, undercurl = true })
hl("SpellCap", { sp = gray, undercurl = true })
hl("SpellLocal", { sp = gray, undercurl = true })
hl("SpellRare", { sp = gray, undercurl = true })

-- errors stay red, warnings and hints are gray
hl("Error", { fg = red, bold = true })
hl("ErrorMsg", { fg = red, bold = true })
hl("DiagnosticError", { fg = red })
hl("DiagnosticWarn", { fg = white })
hl("DiagnosticInfo", { fg = light })
hl("DiagnosticHint", { fg = gray })
hl("DiagnosticOk", { fg = light })

-- a few visual options
vim.o.number = true -- line numbers
vim.o.cursorline = true -- the current line is a bit lighter
vim.opt.fillchars = { eob = " " } -- no ~ on empty lines after the end of file
