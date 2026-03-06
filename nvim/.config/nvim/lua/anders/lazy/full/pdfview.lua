return {
	{
		"basola21/PDFview",
		lazy = false,
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			vim.keymap.set("n", "<leader>pv", function()
				local current = vim.api.nvim_buf_get_name(0)
				if current:lower():match("%.pdf$") then
					require("pdfview").open(current)
					return
				end
				require("pdfview").telescope_open()
			end, { desc = "PDFview: Open PDF picker" })

			vim.keymap.set("n", "<leader>jj", function()
				require("pdfview.renderer").next_page()
			end, { desc = "PDFview: Next page" })

			vim.keymap.set("n", "<leader>kk", function()
				require("pdfview.renderer").previous_page()
			end, { desc = "PDFview: Previous page" })

			vim.api.nvim_create_autocmd("BufReadPost", {
				pattern = "*.pdf",
				callback = function()
					local file_path = vim.api.nvim_buf_get_name(0)
					if file_path == nil or file_path == "" then
						return
					end
					require("pdfview").open(file_path)
				end,
			})
		end,
	},
}
