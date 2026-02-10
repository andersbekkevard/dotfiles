return {
	{
		"akinsho/bufferline.nvim",
		dependencies = { "echasnovski/mini.icons" },
		lazy = false,
		config = function()
			require("bufferline").setup({
				options = {
					mode = "buffers",
					numbers = "ordinal",
					diagnostics = "nvim_lsp",
					show_buffer_close_icons = false,
					show_close_icon = false,
				},
			})
			for i = 1, 9 do
				vim.keymap.set("n", "<C-" .. i .. ">", function()
					require("bufferline").go_to(i, true)
				end, { desc = "Go to buffer " .. i })
			end
		end,
	},
}
