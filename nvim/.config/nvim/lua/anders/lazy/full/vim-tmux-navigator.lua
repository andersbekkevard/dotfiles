return {
	"christoomey/vim-tmux-navigator",
	cmd = {
		"TmuxNavigateLeft",
		"TmuxNavigateDown",
		"TmuxNavigateUp",
		"TmuxNavigateRight",
	},
	keys = {
		{ "<C-h>", "<cmd>TmuxNavigateLeft<cr>",  desc = "Navigate left (vim/tmux)" },
		{ "<C-j>", "<cmd>TmuxNavigateDown<cr>",  desc = "Navigate down (vim/tmux)" },
		{ "<C-k>", "<cmd>TmuxNavigateUp<cr>",    desc = "Navigate up (vim/tmux)" },
		{ "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (vim/tmux)" },
		{ "<C-h>", [[<C-\><C-n><cmd>TmuxNavigateLeft<cr>]],  mode = "t", desc = "Navigate left from terminal" },
		{ "<C-j>", [[<C-\><C-n><cmd>TmuxNavigateDown<cr>]],  mode = "t", desc = "Navigate down from terminal" },
		{ "<C-k>", [[<C-\><C-n><cmd>TmuxNavigateUp<cr>]],    mode = "t", desc = "Navigate up from terminal" },
		{ "<C-l>", [[<C-\><C-n><cmd>TmuxNavigateRight<cr>]], mode = "t", desc = "Navigate right from terminal" },
	},
}
