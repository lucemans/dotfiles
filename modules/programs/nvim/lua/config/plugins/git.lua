require("gitsigns").setup({
  on_attach = function(buffer)
    local gitsigns = require("gitsigns")
    local map = function(keys, action, description)
      vim.keymap.set("n", keys, action, { buffer = buffer, desc = description, silent = true })
    end

    map("]c", gitsigns.next_hunk, "Next git hunk")
    map("[c", gitsigns.prev_hunk, "Previous git hunk")
    map("<leader>gb", gitsigns.blame_line, "Git blame line")
    map("<leader>gp", gitsigns.preview_hunk, "Preview git hunk")
  end,
})
