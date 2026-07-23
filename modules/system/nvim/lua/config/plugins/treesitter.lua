vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "bash",
    "css",
    "html",
    "javascript",
    "javascriptreact",
    "json",
    "jsonc",
    "just",
    "lua",
    "markdown",
    "nix",
    "python",
    "rust",
    "toml",
    "typescript",
    "typescriptreact",
    "vim",
    "yaml",
  },
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

require("nvim-treesitter").setup({
  indent = { enable = true },
})
