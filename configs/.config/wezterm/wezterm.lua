-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.initial_cols = 160
config.initial_rows = 30

-- config.text_background_opacity = 0.3
config.window_background_opacity = 0.9
config.window_decorations = "RESIZE"
config.window_frame = {
  font = wezterm.font { family = 'Roboto', weight = 'Bold' },
  font_size = 12.0,
  active_titlebar_bg = '#333333',
  inactive_titlebar_bg = '#333333',
}

config.colors = {
  tab_bar = {
    inactive_tab_edge = '#575757',
  },
}

config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.8,
}

config.font =
  wezterm.font('FiraCode Nerd Font', { weight = 'Bold' })
-- config.font =
--   wezterm.font('JetBrains Mono', { weight = 'Bold' })
config.font_size = 14
config.color_scheme = 'Github Dark (Gogh)'


return config