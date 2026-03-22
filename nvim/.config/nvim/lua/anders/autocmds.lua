-------------------------------------------------------------------------------
--
-- autocommands
--
-------------------------------------------------------------------------------
-- highlight yanked text
vim.api.nvim_create_autocmd(
	'TextYankPost',
	{
		pattern = '*',
		callback = function()
			vim.highlight.on_yank({ timeout = 500 })
		end
	}
)

-- LSP timeout: stop servers after 5 min unfocused, restart on focus
local lsp_timeout_timer = nil
vim.api.nvim_create_autocmd('FocusLost', {
	callback = function()
		lsp_timeout_timer = vim.defer_fn(function()
			for _, client in ipairs(vim.lsp.get_clients()) do
				client:stop()
			end
		end, 1000 * 60 * 5)
	end,
})
vim.api.nvim_create_autocmd('FocusGained', {
	callback = function()
		if lsp_timeout_timer then
			lsp_timeout_timer:stop()
			lsp_timeout_timer = nil
		end
		if #vim.lsp.get_clients() == 0 then
			vim.cmd('e')
		end
	end,
})
