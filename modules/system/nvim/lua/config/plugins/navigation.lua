local actions = require("telescope.actions")

require("nvim-tree").setup({
  filters = { dotfiles = true },
  renderer = { group_empty = true },
  sort = { sorter = "case_sensitive" },
  view = { width = 30 },
})

require("telescope").setup({
  defaults = {
    file_ignore_patterns = { "%.git/", "node_modules/", "%.venv/" },
  },
  pickers = {
    buffers = {
      mappings = { n = { d = actions.delete_buffer } },
    },
    find_files = {
      hidden = true,
      no_ignore = true,
    },
    live_grep = {
      additional_args = function()
        return { "--hidden" }
      end,
    },
  },
})

require("telescope").load_extension("fzf")
