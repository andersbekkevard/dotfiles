return {
	-------------------------------------------------------------------------------
	--
	-- Oil.nvim - File explorer that lets you edit your filesystem like a buffer
	--
	-------------------------------------------------------------------------------
	{
		"stevearc/oil.nvim",
		dependencies = { "echasnovski/mini.icons" },
		lazy = false,
		opts = {
			view_options = {
				-- Show files and directories that start with "."
				show_hidden = true,
			},
			-- Keymaps in oil buffer
			keymaps = {
				["g?"] = "actions.show_help",
				["<CR>"] = "actions.select",
				["<C-s>"] = "actions.select_vsplit",
				["<C-h>"] = "actions.select_split",
				["<C-t>"] = "actions.select_tab",
				["<C-p>"] = "actions.preview",
				["<C-c>"] = "actions.close",
				["<C-l>"] = "actions.refresh",
				["-"] = "actions.parent",
				["_"] = "actions.open_cwd",
				["`"] = "actions.cd",
				["~"] = "actions.tcd",
				["gs"] = "actions.change_sort",
				["gx"] = "actions.open_external",
				["g."] = "actions.toggle_hidden",
				["g\\"] = "actions.toggle_trash",
			},
		},
		config = function(_, opts)
			require("oil").setup(opts)
			
			-- Global keybinding to open Oil
			vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
		end,
	},
}