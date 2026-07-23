vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.filetype.add({
  extension = {
    mdx = "mdx",
  },
})

local options = vim.opt

options.clipboard = "unnamedplus"
options.completeopt = "menu,menuone,noselect"
options.cursorline = true
options.expandtab = true
options.ignorecase = true
options.number = true
options.relativenumber = true
options.scrolloff = 8
options.shiftwidth = 2
options.signcolumn = "yes"
options.smartcase = true
options.smartindent = true
options.splitbelow = true
options.splitright = true
options.tabstop = 2
options.termguicolors = true
options.undofile = true
options.updatetime = 250
options.winborder = "rounded"
