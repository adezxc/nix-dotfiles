{ pkgs, ... }: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    colorschemes.catppuccin = {
      enable = true;
      settings.flavour = "latte";
    };

    globals.mapleader = " ";

    opts = {
      number = true;
      relativenumber = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      smartindent = true;
      wrap = false;
      scrolloff = 8;
      signcolumn = "yes";
      updatetime = 50;
      termguicolors = true;
      guicursor = "n-v-c-sm:block-Cursor,i-ci-ve:ver25-Cursor,r-cr-o:hor20-Cursor";
    };

    highlightOverride.Cursor = {
      fg = "#ffffff";
      bg = "#e64500";
    };

    plugins = {
      # Syntax highlighting
      treesitter = {
        enable = true;
        settings.highlight.enable = true;
        settings.indent.enable = true;
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          go
          nix
          lua
          bash
          json
          yaml
          toml
          typescript
          capnp
          markdown
          python
        ];
      };

      # LSP
      lsp = {
        enable = true;
        servers = {
          gopls.enable = true;
          nixd.enable = true;
        };
        keymaps = {
          lspBuf = {
            "gd" = "definition";
            "gr" = "references";
            "K" = "hover";
            "<leader>rn" = "rename";
            "<leader>ca" = "code_action";
          };
          diagnostic = {
            "<leader>d" = "open_float";
            "[d" = "goto_prev";
            "]d" = "goto_next";
          };
        };
      };

      # Completion
      cmp = {
        enable = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "buffer"; }
            { name = "path"; }
          ];
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>" = "cmp.mapping.abort()";
            "<C-y>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
          };
        };
      };
      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      luasnip.enable = true;
      cmp_luasnip.enable = true;

      web-devicons.enable = true;

      # Telescope
      telescope = {
        enable = true;
        extensions.fzf-native.enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
          "<leader>fd" = "diagnostics";
        };
      };

      # Git signs in the gutter
      gitsigns = {
        enable = true;
        settings.signs = {
          add.text = "│";
          change.text = "│";
          delete.text = "_";
          topdelete.text = "‾";
          changedelete.text = "~";
        };
      };

      # Status line
      lualine = {
        enable = true;
      };

      # Comment toggling
      comment.enable = true;

      # Show pending keybinds
      which-key.enable = true;

      # Auto close brackets/quotes
      nvim-autopairs.enable = true;

      # Indent guides
      indent-blankline.enable = true;

      # Formatter
      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft = {
            go = [ "goimports" "gofmt" ];
            nix = [ "alejandra" ];
          };
          format_on_save = {
            timeout_ms = 1000;
            lsp_fallback = true;
          };
        };
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>F";
        action.__raw = "function() require('conform').format({ lsp_fallback = true }) end";
        options.desc = "Format buffer";
      }
    ];
  };
}
