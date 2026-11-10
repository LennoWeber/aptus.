 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#f4ede1',
    base01 = '#ebe3d5',
    base02 = '#e2d8c8',
    base03 = '#a0948a',
    base04 = '#3b3329',
    base05 = '#272119',
    base06 = '#272119',
    base07 = '#272119',
    base08 = '#b03522',
    base09 = '#1f5f86',
    base0A = '#1f5f86',
    base0B = '#1f5f86',
    base0C = '#1f5f86',
    base0D = '#1f5f86',
    base0E = '#1f5f86',
    base0F = '#1f5f86',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#272119',          bg = '#f4ede1' })
  hi('TelescopeBorder',         { fg = '#a0948a',             bg = '#f4ede1' })
  hi('TelescopePromptNormal',   { fg = '#272119',          bg = '#f4ede1' })
  hi('TelescopePromptBorder',   { fg = '#a0948a',             bg = '#f4ede1' })
  hi('TelescopePromptPrefix',   { fg = '#1f5f86',             bg = '#f4ede1' })
  hi('TelescopePromptCounter',  { fg = '#3b3329',  bg = '#f4ede1' })
  hi('TelescopePromptTitle',    { fg = '#f4ede1',             bg = '#1f5f86' })
  hi('TelescopePreviewTitle',   { fg = '#f4ede1',             bg = '#1f5f86' })
  hi('TelescopeResultsTitle',   { fg = '#f4ede1',             bg = '#1f5f86' })
  hi('TelescopeSelection',      { fg = '#272119',          bg = '#e2d8c8' })
  hi('TelescopeSelectionCaret', { fg = '#1f5f86',             bg = '#e2d8c8' })
  hi('TelescopeMatching',       { fg = '#1f5f86',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#272119',          bg = '#f4ede1' })
  hi('MiniPickBorder',         { fg = '#a0948a',             bg = '#f4ede1' })
  hi('MiniPickPrompt',   { fg = '#272119',          bg = '#f4ede1' })
  hi('MiniPickPromptPrefix',   { fg = '#1f5f86',             bg = '#f4ede1' })
  hi('MiniPickBorderText',    { fg = '#f4ede1',             bg = '#1f5f86' })
  hi('MiniPickMatchCurrent',      { fg = '#272119',          bg = '#e2d8c8' })
  hi('MiniPickPromptCaret', { fg = '#1f5f86',             bg = '#e2d8c8' })
  hi('MiniPickMatchRanges',       { fg = '#1f5f86',             bold = true })
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
