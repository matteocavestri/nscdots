-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- neovide configuration
if vim.g.neovide then
  -- Helper function for transparency formatting
  -- NOTE: This is deprecated, see https://github.com/neovide/neovide/issues/2168
  local alpha = function()
    return string.format("%x", math.floor((255 * vim.g.transparency) or 0.8))
  end
  -- g:neovide_transparency should be 0 if you want to unify transparency of content and title bar.
  vim.g.neovide_transparency = 0.0
  vim.g.transparency = 0.8
  vim.g.neovide_background_color = "#0f1117" .. alpha()
end
