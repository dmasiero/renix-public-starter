{ pkgs, ... }:
{
  # neovim
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    plugins = with pkgs.vimPlugins; [
      vim-surround
      vim-commentary
      vim-repeat
      vim-unimpaired
      vim-fugitive
      catppuccin-nvim
      lualine-nvim
      nvim-web-devicons
      gitsigns-nvim
      bufferline-nvim
      mini-nvim
      telescope-nvim
      plenary-nvim
      telescope-fzf-native-nvim
      oil-nvim
    ];

    extraLuaConfig = ''
      vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "
      vim.opt.clipboard = "unnamedplus"
      -- Use OSC 52 to yank to the system clipboard over SSH/remote sessions.
      -- Copy uses OSC 52 escape sequences that the terminal emulator
      -- (e.g. Blink Shell) interprets as "set the system clipboard."
      -- Paste falls back to Neovim's internal registers since most terminals
      -- do not support OSC 52 paste (reading the clipboard).
      local function paste()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
      end
      vim.g.clipboard = {
        name = "OSC 52",
        copy = {
          ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
          ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
        },
        paste = {
          ["+"] = paste,
          ["*"] = paste,
        },
      }
      vim.api.nvim_set_hl(0, "Normal",     { bg = "none" })
      vim.api.nvim_set_hl(0, "NonText",    { bg = "none" })
      vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
      require("mini.pairs").setup()
      require("mini.jump").setup()

      -- Oil
      require("oil").setup({
        view_options = {
          show_hidden = true,
          is_always_hidden = function(name, _)
            return name == ".."
          end,
        },
        win_options = {
          number = false,
          relativenumber = false,
        },
        keymaps = {
          ["<BS>"] = "actions.parent",
          ["h"] = "actions.parent",
          ["-"] = "actions.parent",
        },
      })
      vim.keymap.set("n", "<leader>e", "<CMD>Oil<CR>", { desc = "Open parent directory" })

      -- Catppuccin
      require("catppuccin").setup({ flavour = "mocha", transparent_background = true })
      vim.cmd.colorscheme "catppuccin"

      -- Lualine
      require("lualine").setup({ options = { theme = "catppuccin", globalstatus = true } })

      -- Telescope
      require("telescope").setup({
        extensions = {
          fzf = {
            fuzzy = true,
            case_mode = "smart_case",
          },
        },
      })

      -- Gitsigns: git signs + relative line numbers
      require("gitsigns").setup({
        signs = {
          add          = { text = "▎" },
          change       = { text = "▎" },
          delete       = { text = "" },
          topdelete    = { text = "" },
          changedelete = { text = "▎" },
        },
        current_line_blame = false,
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
      })

      -- Relative + hybrid line numbers
      vim.opt.number = true
      vim.opt.relativenumber = true

      -- Make the current line show absolute number, others relative
      vim.api.nvim_create_autocmd({ "InsertEnter" }, {
        pattern = "*",
        callback = function() vim.opt.relativenumber = false end,
      })
      vim.api.nvim_create_autocmd({ "InsertLeave" }, {
        pattern = "*",
        callback = function() vim.opt.relativenumber = true end,
      })

      -- Bufferline
      require("bufferline").setup({
        options = {
          mode = "buffers",
          separator_style = "thin",
          always_show_bufferline = false,
          show_buffer_close_icons = true,
          show_close_icon = false,
          color_icons = true,
          diagnostics = "nvim_lsp",
        },
      })

      -- Keybindings
      vim.keymap.set("n", "<Tab>",   "<cmd>BufferLineCycleNext<CR>", { silent = true })
      vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>", { silent = true })

      -- <leader>1 .. <leader>9 to jump to specific tab
      for i = 1, 9 do
        vim.keymap.set("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<CR>", { silent = true })
      end
      vim.keymap.set("n", "<leader>$", "<cmd>BufferLineGoToBuffer -1<CR>", { desc = "Last buffer" })

      require("telescope").load_extension("fzf")
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep,  { desc = "Grep project" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers,    { desc = "Buffers" })
      vim.keymap.set("n", "<leader>fr", builtin.oldfiles,   { desc = "Recent files" })
    '';
  };
}
