return {
  {
    "ibhagwan/fzf-lua",
    -- Optional for icon support
    dependencies = { "nvim-tree/nvim-web-devicons" }, 
    cmd = "FzfLua",
    opts = function()
      -- Sane default layout configurations
      return {
        winopts = {
          height = 0.85,
          width = 0.80,
          row = 0.35,
          col = 0.50,
          preview = {
            layout = "horizontal",
            horizontal = "right:50%",
          },
        },
      }
    end,
    keys = {
      -- Define basic keymaps for quick fzf-lua access
      { "<leader>zf", "<cmd>FzfLua files<cr>", desc = "Find Files (fzf)" },
      { "<leader>zg", "<cmd>FzfLua live_grep<cr>", desc = "Live Grep (fzf)" },
      { "<leader>zb", "<cmd>FzfLua buffers<cr>", desc = "Buffers (fzf)" },
      { "<leader>zh", "<cmd>FzfLua help_tags<cr>", desc = "Help Tags (fzf)" },
    },
  },
}

