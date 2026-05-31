return {
	-------------------------------------------------------------------------------
	--
	-- Claude Code in Neovim (coder/claudecode.nvim)
	--
	-- Primary keybind: <leader>ac toggles the Claude Code terminal.
	-- Other defaults under <leader>a*: f focus, r resume, C continue,
	-- s send selection, o add buffer, aa accept diff, ad deny diff.
	--
	-------------------------------------------------------------------------------
	{
		"coder/claudecode.nvim",
		dependencies = { "folke/snacks.nvim" },
		cmd = {
			"ClaudeCode",
			"ClaudeCodeFocus",
			"ClaudeCodeResume",
			"ClaudeCodeContinue",
			"ClaudeCodeSend",
			"ClaudeCodeTreeAdd",
			"ClaudeCodeAdd",
			"ClaudeCodeDiffAccept",
			"ClaudeCodeDiffDeny",
		},
		keys = {
			{ "<leader>a", nil, desc = "AI/Claude Code" },
			{ "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" },
			{ "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude Code" },
			{ "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
			{ "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
			{ "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection" },
			{
				"<leader>as",
				"<cmd>ClaudeCodeTreeAdd<cr>",
				desc = "Add file from tree",
				ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
			},
			{ "<leader>ao", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
			{ "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
			{ "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
		},
		opts = {},
	},
}
