-- In-buffer Markdown / HTML / LaTeX / Typst / YAML previewer
-- https://github.com/OXY2DEV/markview.nvim
--
-- Do not lazy-load: the plugin is already lazy-loaded internally.
-- Load after colorscheme so highlight groups resolve correctly.

---@type LazySpec
return {
  "OXY2DEV/markview.nvim",
  lazy = false,
  -- Callout / checkbox completions (you already have blink.cmp via AstroNvim)
  dependencies = {
    "saghen/blink.cmp",
  },
  opts = {
    preview = {
      -- AstroNvim ships mini.icons; alternatives: "internal" | "devicons"
      icon_provider = "mini",
    },
  },
}
