local conform = require("conform")

local function format(buffer, notify)
  if #conform.list_formatters_to_run(buffer) == 0 then
    if notify then
      vim.notify("No project formatter is available for this buffer", vim.log.levels.WARN)
    end
    return
  end

  conform.format({
    async = false,
    bufnr = buffer,
    lsp_format = "never",
    timeout_ms = 2000,
  })
end

conform.setup({
  format_on_save = function(buffer)
    if #conform.list_formatters_to_run(buffer) == 0 then
      return
    end

    return { lsp_format = "never", timeout_ms = 2000 }
  end,
  formatters_by_ft = {
    javascript = { "eslint_d", "prettier", stop_after_first = true },
    javascriptreact = { "eslint_d", "prettier", stop_after_first = true },
    json = { "jq" },
    jsonc = { "prettier" },
    lua = { "stylua" },
    markdown = { "prettier" },
    mdx = { "prettier" },
    nix = { "alejandra" },
    python = { "ruff_format" },
    rust = { "rustfmt" },
    toml = { "taplo" },
    typescript = { "eslint_d", "prettier", stop_after_first = true },
    typescriptreact = { "eslint_d", "prettier", stop_after_first = true },
    yaml = { "prettier" },
  },
})

vim.keymap.set("n", "<leader>f", function()
  format(0, true)
end, { desc = "Format buffer" })
