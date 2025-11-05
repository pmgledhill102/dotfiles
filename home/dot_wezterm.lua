local wezterm = require 'wezterm'
local config = {}

config.keys = {
  ---------------------------------
  -- Your Personal Bindings
  ---------------------------------
  { key = '3', mods = 'OPT', action = wezterm.action.SendString('#') },
  { key = '2', mods = 'OPT', action = wezterm.action.SendString('€') },
  { key = 'LeftArrow', mods = 'OPT', action = wezterm.action.SendString('\x1bb') },
  { key = 'RightArrow', mods = 'OPT', action = wezterm.action.SendString('\x1bf') },
  { key = 'k', mods = 'CMD', action = wezterm.action.ClearScrollback('ScrollbackAndViewport') },

  ---------------------------------
  -- Pane Splitting (iTerm2-style)
  ---------------------------------
  { key = 'd', mods = 'CMD', action = wezterm.action.SplitVertical{ domain = 'CurrentPaneDomain' } },
  { key = 'd', mods = 'CMD|SHIFT', action = wezterm.action.SplitHorizontal{ domain = 'CurrentPaneDomain' } },
  { key = ']', mods = 'CMD', action = wezterm.action.ActivatePaneDirection('Next') },
  { key = '[', mods = 'CMD', action = wezterm.action.ActivatePaneDirection('Prev') },

  ---------------------------------
  -- Tab Navigation
  ---------------------------------
  { key = '1', mods = 'CMD', action = wezterm.action.ActivateTab(0) },
  { key = '2', mods = 'CMD', action = wezterm.action.ActivateTab(1) },
  { key = '3', mods = 'CMD', action = wezterm.action.ActivateTab(2) },
  { key = '4', mods = 'CMD', action = wezterm.action.ActivateTab(3) },
  { key = '5', mods = 'CMD', action = wezterm.action.ActivateTab(4) },
  { key = '6', mods = 'CMD', action = wezterm.action.ActivateTab(5) },
  { key = '7', mods = 'CMD', action = wezterm.action.ActivateTab(6) },
  { key = '8', mods = 'CMD', action = wezterm.action.ActivateTab(7) },
  { key = '9', mods = 'CMD', action = wezterm.action.ActivateTab(8) },
}

-- Simple validation function
local function validate_config(cfg)
  -- Basic sanity checks
  if type(cfg) ~= "table" then
    return false, "Config must be a table"
  end
  
  if cfg.keys and type(cfg.keys) ~= "table" then
    return false, "config.keys must be a table"
  end
  
  if cfg.keys then
    for i, binding in ipairs(cfg.keys) do
      if not binding.key then
        return false, "Key binding " .. i .. " missing 'key' field"
      end
      if not binding.action then
        return false, "Key binding " .. i .. " missing 'action' field"
      end
    end
  end
  
  return true, "Config validation passed"
end

-- Validate before returning
local ok, msg = validate_config(config)
if not ok then
  -- Log error but don't fail completely
  wezterm.log_error("WezTerm config validation: " .. msg)
end

-- Return the configuration
return config