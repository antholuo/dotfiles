-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- ---------------------------------------------------------------------------
-- Trailing whitespace: highlight (red/orange) + strip on <F8>
-- ---------------------------------------------------------------------------

-- listchars left off (would show trail/tab glyphs); ExtraWhitespace match is enough.
-- vim.opt.list = true
-- vim.opt.listchars = {
--   tab = "» ",
--   trail = "·",
--   nbsp = "␣",
--   extends = "›",
--   precedes = "‹",
-- }

-- Strong red/orange background on trailing whitespace
local function set_extra_whitespace_hl()
  vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "#e06c75", ctermbg = "red" })
end
set_extra_whitespace_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "Re-apply ExtraWhitespace highlight after colorscheme change",
  callback = set_extra_whitespace_hl,
})

-- Window-local match; skip special buffers (terminal, help, etc.)
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "InsertLeave" }, {
  desc = "Highlight trailing whitespace",
  callback = function()
    if vim.bo.buftype ~= "" then return end
    -- Avoid stacking matchadd: one :match per window
    vim.cmd [[match ExtraWhitespace /\s\+$/]]
  end,
})
-- Soften while typing so the space under the cursor isn't noisy
vim.api.nvim_create_autocmd("InsertEnter", {
  desc = "Don't highlight trailing space under cursor in insert mode",
  callback = function()
    if vim.bo.buftype ~= "" then return end
    vim.cmd [[match ExtraWhitespace /\s\+\%#\@<!$/]]
  end,
})

-- <F8>: strip all trailing whitespace (preserves search register + view)
vim.keymap.set("n", "<F8>", function()
  local view = vim.fn.winsaveview()
  local search = vim.fn.getreg "/"
  vim.cmd [[%s/\s\+$//e]]
  vim.fn.setreg("/", search)
  vim.fn.winrestview(view)
  vim.notify("Stripped trailing whitespace", vim.log.levels.INFO)
end, { desc = "Strip trailing whitespace" })

-- Visual mode: strip only in the selection
vim.keymap.set("x", "<F8>", function()
  local search = vim.fn.getreg "/"
  vim.cmd [['<,'>s/\s\+$//e]]
  vim.fn.setreg("/", search)
  vim.notify("Stripped trailing whitespace in selection", vim.log.levels.INFO)
end, { desc = "Strip trailing whitespace (selection)" })
