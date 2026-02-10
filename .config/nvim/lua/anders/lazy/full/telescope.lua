return {
	-------------------------------------------------------------------------------
	--
	-- Telescope
	--
	-------------------------------------------------------------------------------
	{
		"nvim-telescope/telescope.nvim",
		-- Remove tag to get latest version
		dependencies = {
			"nvim-lua/plenary.nvim"
		},
		config = function()
			-- Suppress deprecated API warnings by setting deprecation level
			vim.deprecate = function() end

			require('telescope').setup({
				defaults = {
					mappings = {
						i = {
							["<C-c>"] = require('telescope.actions').close,
						},
					},
				},
			})

			local builtin = require('telescope.builtin')

			-- Quick access to telescope builtins
			vim.keymap.set('n', '<C-t>', builtin.builtin, { desc = 'Telescope builtins' })

			-- Find keybinds (<leader>f*)
			vim.keymap.set('n', '<leader>ff', function()
				builtin.find_files({ hidden = true })
			end, { desc = 'Find files (including hidden)' })
			vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Find grep (live)' })
			vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
			vim.keymap.set('n', '<C-b>', builtin.buffers, { desc = 'Find buffers' })
			vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Find help' })
			vim.keymap.set('n', '<leader>fw', function()
				builtin.grep_string({ search = vim.fn.expand("<cword>") })
			end, { desc = 'Find word under cursor' })
			vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = 'Find recent files' })

			-- Commented out: grep with command-line input (use <leader>fg live_grep instead)
			-- vim.keymap.set('n', '<leader>sg', function()
			-- 	builtin.grep_string({ search = vim.fn.input("Grep > ") })
			-- end, { desc = 'Grep with prompt' })
		end
	},
}
