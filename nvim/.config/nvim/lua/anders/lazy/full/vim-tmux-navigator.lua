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
	},
}
