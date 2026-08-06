-- This file simply bootstraps the installation of Lazy.nvim and then calls other files for execution
-- This file doesn't necessarily need to be touched, BE CAUTIOUS editing this file and proceed at your own risk.
local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  -- stylua: ignore
  local result = vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
  if vim.v.shell_error ~= 0 then
    -- stylua: ignore
    vim.api.nvim_echo({ { ("Error cloning lazy.nvim:\n%s\n"):format(result), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
  end
end

vim.opt.rtp:prepend(lazypath)

-- validate that lazy is available
if not pcall(require, "lazy") then
  -- stylua: ignore
  vim.api.nvim_echo({ { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end

require "lazy_setup"
require "polish"

vim.keymap.set("n", "<leader>gy", function()
  -- Get the absolute path of the current buffer
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then
    print("No file open")
    return
  end

  -- Let Git calculate the exact relative path from the repository root
  local cmd = string.format("git ls-files --full-name %s", vim.fn.shellescape(current_file))
  local result = vim.fn.system(cmd):gsub("%s+$", "") -- Execute and trim trailing newlines

  -- Check if the file is tracked/inside a Git repository
  if vim.v.shell_error ~= 0 or result == "" then
    print("Not a git repository or file not tracked")
    return
  end

  -- Copy the string straight to your system register "+"
  vim.fn.setreg("+", result)
  print("Copied relative Git path: " .. result)
end, { desc = "Copy file path relative to Git root" })
