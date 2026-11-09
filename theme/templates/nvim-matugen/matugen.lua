 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '{{ ground }}',
    base01 = '{{ raised }}',
    base02 = '{{ raisedHot }}',
    base03 = '{{ inkFaint }}',
    base04 = '{{ inkSec }}',
    base05 = '{{ inkMain }}',
    base06 = '{{ inkMain }}',
    base07 = '{{ inkMain }}',
    base08 = '{{ crit }}',
    base09 = '{{ accent }}',
    base0A = '{{ accent }}',
    base0B = '{{ accent }}',
    base0C = '{{ accent }}',
    base0D = '{{ accent }}',
    base0E = '{{ accent }}',
    base0F = '{{ accent }}',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '{{ inkMain }}',          bg = '{{ ground }}' })
  hi('TelescopeBorder',         { fg = '{{ inkFaint }}',             bg = '{{ ground }}' })
  hi('TelescopePromptNormal',   { fg = '{{ inkMain }}',          bg = '{{ ground }}' })
  hi('TelescopePromptBorder',   { fg = '{{ inkFaint }}',             bg = '{{ ground }}' })
  hi('TelescopePromptPrefix',   { fg = '{{ accent }}',             bg = '{{ ground }}' })
  hi('TelescopePromptCounter',  { fg = '{{ inkSec }}',  bg = '{{ ground }}' })
  hi('TelescopePromptTitle',    { fg = '{{ ground }}',             bg = '{{ accent }}' })
  hi('TelescopePreviewTitle',   { fg = '{{ ground }}',             bg = '{{ accent }}' })
  hi('TelescopeResultsTitle',   { fg = '{{ ground }}',             bg = '{{ accent }}' })
  hi('TelescopeSelection',      { fg = '{{ inkMain }}',          bg = '{{ raisedHot }}' })
  hi('TelescopeSelectionCaret', { fg = '{{ accent }}',             bg = '{{ raisedHot }}' })
  hi('TelescopeMatching',       { fg = '{{ accent }}',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '{{ inkMain }}',          bg = '{{ ground }}' })
  hi('MiniPickBorder',         { fg = '{{ inkFaint }}',             bg = '{{ ground }}' })
  hi('MiniPickPrompt',   { fg = '{{ inkMain }}',          bg = '{{ ground }}' })
  hi('MiniPickPromptPrefix',   { fg = '{{ accent }}',             bg = '{{ ground }}' })
  hi('MiniPickBorderText',    { fg = '{{ ground }}',             bg = '{{ accent }}' })
  hi('MiniPickMatchCurrent',      { fg = '{{ inkMain }}',          bg = '{{ raisedHot }}' })
  hi('MiniPickPromptCaret', { fg = '{{ accent }}',             bg = '{{ raisedHot }}' })
  hi('MiniPickMatchRanges',       { fg = '{{ accent }}',             bold = true })
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
