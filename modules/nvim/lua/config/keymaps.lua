local map = vim.keymap.set

map("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree", silent = true })
map("n", "<leader>e", "<cmd>NvimTreeFindFile<CR>", { desc = "Reveal file in tree", silent = true })
map("n", "<leader>r", "<cmd>NvimTreeRefresh<CR>", { desc = "Refresh file tree", silent = true })

map("n", "<C-f>", function()
  require("telescope.builtin").find_files()
end, { desc = "Find files", silent = true })
map("n", "<leader>ff", function()
  require("telescope.builtin").find_files()
end, { desc = "Find files", silent = true })
map("n", "<leader>fg", function()
  require("telescope.builtin").live_grep()
end, { desc = "Grep files", silent = true })
map("n", "<leader>fb", function()
  require("telescope.builtin").buffers()
end, { desc = "Find buffers", silent = true })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer", silent = true })

map("n", "ss", function()
  require("flash").jump()
end, { desc = "Flash jump", silent = true })
map("n", "S", function()
  require("flash").treesitter()
end, { desc = "Flash Tree-sitter jump", silent = true })

map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic", silent = true })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic", silent = true })
