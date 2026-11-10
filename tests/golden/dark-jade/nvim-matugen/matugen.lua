 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#191613',
    base01 = '#231f1b',
    base02 = '#2c2722',
    base03 = '#7f756a',
    base04 = '#d3c8b3',
    base05 = '#efe6d4',
    base06 = '#efe6d4',
    base07 = '#efe6d4',
    base08 = '#fa9d86',
    base09 = '#9acfae',
    base0A = '#9acfae',
    base0B = '#9acfae',
    base0C = '#9acfae',
    base0D = '#9acfae',
    base0E = '#9acfae',
    base0F = '#9acfae',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#efe6d4',          bg = '#191613' })
  hi('TelescopeBorder',         { fg = '#7f756a',             bg = '#191613' })
  hi('TelescopePromptNormal',   { fg = '#efe6d4',          bg = '#191613' })
  hi('TelescopePromptBorder',   { fg = '#7f756a',             bg = '#191613' })
  hi('TelescopePromptPrefix',   { fg = '#9acfae',             bg = '#191613' })
  hi('TelescopePromptCounter',  { fg = '#d3c8b3',  bg = '#191613' })
  hi('TelescopePromptTitle',    { fg = '#191613',             bg = '#9acfae' })
  hi('TelescopePreviewTitle',   { fg = '#191613',             bg = '#9acfae' })
  hi('TelescopeResultsTitle',   { fg = '#191613',             bg = '#9acfae' })
  hi('TelescopeSelection',      { fg = '#efe6d4',          bg = '#2c2722' })
  hi('TelescopeSelectionCaret', { fg = '#9acfae',             bg = '#2c2722' })
  hi('TelescopeMatching',       { fg = '#9acfae',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#efe6d4',          bg = '#191613' })
  hi('MiniPickBorder',         { fg = '#7f756a',             bg = '#191613' })
  hi('MiniPickPrompt',   { fg = '#efe6d4',          bg = '#191613' })
  hi('MiniPickPromptPrefix',   { fg = '#9acfae',             bg = '#191613' })
  hi('MiniPickBorderText',    { fg = '#191613',             bg = '#9acfae' })
  hi('MiniPickMatchCurrent',      { fg = '#efe6d4',          bg = '#2c2722' })
  hi('MiniPickPromptCaret', { fg = '#9acfae',             bg = '#2c2722' })
  hi('MiniPickMatchRanges',       { fg = '#9acfae',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
