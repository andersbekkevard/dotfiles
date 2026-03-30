return {
	-------------------------------------------------------------------------------
	--
	-- Telescope
	--
	-------------------------------------------------------------------------------
	{
		"nvim-telescope/telescope.nvim",
		lazy = false,
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
							["<C-j>"] = require('telescope.actions').move_selection_next,
							["<C-k>"] = require('telescope.actions').move_selection_previous,
						},
						n = {
							["<C-j>"] = require('telescope.actions').move_selection_next,
							["<C-k>"] = require('telescope.actions').move_selection_previous,
						},
					},
				},
			})

			local builtin = require('telescope.builtin')
			local hidden_rg_args = function()
				return { "--hidden", "--glob", "!**/.git/*" }
			end

			-- Quick access to telescope builtins
			vim.keymap.set('n', '<C-t>', builtin.builtin, { desc = 'Telescope builtins' })

			-- Find keybinds (<leader>f*)
			vim.keymap.set('n', '<leader>ff', function()
				builtin.find_files({ hidden = true })
			end, { desc = 'Find files (including hidden)' })
			vim.keymap.set('n', '<leader>fg', function()
				builtin.live_grep({ additional_args = hidden_rg_args })
			end, { desc = 'Find grep (live, includes hidden)' })
			vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
			vim.keymap.set('n', '<C-b>', builtin.buffers, { desc = 'Find buffers' })
			vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Find help' })
			vim.keymap.set('n', '<leader>fw', function()
				builtin.grep_string({ search = vim.fn.expand("<cword>") })
			end, { desc = 'Find word under cursor' })
			vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = 'Find recent files' })
			vim.keymap.set('n', '<leader>fd', function()
				builtin.find_files({
					find_command = { "fd", "--type", "d", "--hidden", "--exclude", ".git", "--exclude", ".venv", "--exclude", "node_modules" },
					prompt_title = "Find Directory",
					attach_mappings = function(prompt_bufnr, map)
						local actions = require("telescope.actions")
						local action_state = require("telescope.actions.state")
						actions.select_default:replace(function()
							local entry = action_state.get_selected_entry()
							actions.close(prompt_bufnr)
							local dir = vim.fn.fnamemodify(entry[1], ":p")
							vim.cmd.cd(dir)
							require("oil").open(dir)
						end)
						return true
					end,
				})
			end, { desc = 'Find directory (cd + Oil)' })

			-- Commented out: grep with command-line input (use <leader>fg live_grep instead)
			-- vim.keymap.set('n', '<leader>sg', function()
			-- 	builtin.grep_string({ search = vim.fn.input("Grep > ") })
			-- end, { desc = 'Grep with prompt' })
		end
	},
}
