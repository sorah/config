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
  'Noto Sans CJK JP',
  'Noto Sans JP',
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

local bg_image_path = wezterm.home_dir .. (is_windows and '\\Pictures\\wezterm.jpg' or '/Pictures/wezterm.jpg')
local bg_transparent = {
  {
    source = { Color = "#0c0c0c" },
    width = "100%",
    height = "100%",
    opacity = 0.90,
  },
}
local bg_image = {
  {
    source = { File = bg_image_path },
    height = "Cover",
    vertical_align = "Middle",
    hsb = { brightness = 0.02, hue = 1.0, saturation = 1.0 },
  },
}
config.background = bg_transparent

local bg_image_active = false
wezterm.on('toggle-background', function(window, _pane)
  bg_image_active = not bg_image_active
  window:set_config_overrides({
    background = bg_image_active and bg_image or bg_transparent,
  })
end)

config.keys = {
  { mods = 'ALT', key = 'c', action = wezterm.action.CopyTo 'Clipboard' },
  { mods = 'ALT', key = 'v', action = wezterm.action.PasteFrom 'Clipboard' },
  { mods = 'ALT', key = '.', action = wezterm.action.CharSelect {
  }},
  { mods = 'CTRL|SHIFT', key = 'b', action = wezterm.action.EmitEvent 'toggle-background' },
}

config.detect_password_input = true

config.canonicalize_pasted_newlines = "CarriageReturn"

return config
