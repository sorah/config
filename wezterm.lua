local wezterm = require 'wezterm'
local config = {}

local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc" 

if is_windows then
  config.default_prog = { 'pwsh' }
end

config.font = wezterm.font_with_fallback{
  {
    family = 'Source Code Pro',
    weight = 'Regular',
    assume_emoji_presentation = false,
   },
  'Noto Sans JP',
  'Noto Sans CJK JP',
}
config.cell_width = 0.8
config.line_height = 1.0
config.font_size = 11
--config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

config.color_scheme = 'Tango (terminal.sexy)'
config.colors = {
  background = "#0c0c0c",
  foreground = "#d8d8d8",
}
config.window_background_opacity = 0.90

config.window_frame = {
  font = wezterm.font_with_fallback{
    { family = 'Source Sans 3', assume_emoji_presentation = false },
    { family = 'Source Sans Pro', assume_emoji_presentation = false },
    { family = 'Noto Sans CJK JP', weight = 'Medium' },
    { family = 'Noto Sans JP', weight = 'Medium' },
    { family = 'Noto Sans', weight = 'Medium' },
  },
  font_size = 8,
}
config.command_palette_font_size = 10.0
config.char_select_font_size = 12.0
config.hide_tab_bar_if_only_one_tab = true

config.window_padding = {
  left = '0.2cell',
  right = '0.2cell',
  top = '0cell',
  bottom = '0cell',
}

config.keys = {
  { mods = 'ALT', key = 'c', action = wezterm.action.CopyTo 'Clipboard' },
  { mods = 'ALT', key = 'v', action = wezterm.action.PasteFrom 'Clipboard' },
  { mods = 'ALT', key = '.', action = wezterm.action.CharSelect {
  }},
}

config.detect_password_input = true

config.canonicalize_pasted_newlines = "CarriageReturn"

return config
