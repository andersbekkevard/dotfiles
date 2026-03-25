-- Zoxide integration via Telescope
-- No external plugin needed; uses zoxide CLI + core telescope APIs.
-- Keymaps: <leader>cd / <leader>fz → zoxide picker, cd + open Oil on select.
return {
	{
		"nvim-telescope/telescope.nvim",
		keys = {
			{
				"<leader>cd",
				function() require("anders.zoxide").list() end,
				desc = "Zoxide cd",
			},
			{
				"<leader>fz",
				function() require("anders.zoxide").list() end,
				desc = "Find zoxide directory",
			},
		},
	},
}
