-- Dynamic plugin loading based on environment
if vim.g.vscode then
	-- VS Code/Cursor specific plugins
	return {
		require("anders.lazy.shared.flash"),
		require("anders.lazy.vscode.highlight"),
	}
else
	-- Full Neovim plugins
	return {
		require("anders.lazy.full.theme"),
		require("anders.lazy.full.lsp"),
		require("anders.lazy.full.completion"),
		require("anders.lazy.full.telescope"),
		require("anders.lazy.shared.flash"),
		require("anders.lazy.full.oil"),
		require("anders.lazy.full.vim-be-good"),
		require("anders.lazy.full.lazygit"),
	}
end
