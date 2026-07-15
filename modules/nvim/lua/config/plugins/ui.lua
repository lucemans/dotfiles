require("mini.ai").setup()
require("mini.indentscope").setup({ symbol = "|" })
require("mini.surround").setup()
require("mini.sessions").setup({
  autoread = true,
  autowrite = true,
  file = ".session",
  force = { delete = true, read = false, write = true },
})

vim.keymap.set("n", "<leader>qs", function()
  require("mini.sessions").write(".session")
end, { desc = "Save session", silent = true })
vim.keymap.set("n", "<leader>qd", function()
  require("mini.sessions").delete(".session")
end, { desc = "Delete session", silent = true })

require("lualine").setup({
  options = {
    globalstatus = true,
    theme = "auto",
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { "filename" },
    lualine_x = { "filetype", "lsp_status" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

vim.g.startify_custom_header = {
  "  Keybindings",
  "  Files: <C-f>/<Space>ff find | <Space>fg grep | <Space>fb buffers | <C-n> tree",
  "  Git: ]c/[c hunks | <Space>gb blame | <Space>gp preview",
  "  LSP: gd definition | gr references | K hover | <Space>ca action | <Space>rn rename",
  "  Edit: <Space>f format | <Space>oi organize imports | ss jump | S treesitter jump",
  "  Sessions: <Space>qs save | <Space>qd delete",
}
vim.g.startify_change_to_vcs_root = 0
vim.g.startify_lists = {
  { header = { "  Recent files" }, type = "files" },
}
