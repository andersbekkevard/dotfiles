return {
	-------------------------------------------------------------------------------
	--
	-- VS Code Highlight on Yank
	--
	-------------------------------------------------------------------------------
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		keys = {
			{ "<leader>wk", function() require("which-key").show({ global = false }) end, desc = "Buffer local keymaps" },
		},
		config = function()
			-- Highlight on yank
			local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
			vim.api.nvim_create_autocmd('TextYankPost', {
				callback = function()
					vim.highlight.on_yank()
				end,
				group = highlight_group,
				pattern = '*',
			})
		end,
	},
}