return {
	-------------------------------------------------------------------------------
	--
	-- nvim-dbee - Database client for Neovim
	--
	-------------------------------------------------------------------------------
	{
		"kndndrj/nvim-dbee",
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
		build = function()
			require("dbee").install()
		end,
		config = function()
			require("dbee").setup()

			-- Keybindings for database operations
			vim.keymap.set("n", "<leader>db", function()
				require("dbee").toggle()
			end, { desc = "Toggle Dbee UI" })

			vim.keymap.set("n", "<leader>do", function()
				require("dbee").open()
			end, { desc = "Open Dbee UI" })

			vim.keymap.set("n", "<leader>dc", function()
				require("dbee").close()
			end, { desc = "Close Dbee UI" })
		end,
	},
}
