return {
	-------------------------------------------------------------------------------
	--
	-- LSP
	--
	-------------------------------------------------------------------------------
	{
		'neovim/nvim-lspconfig',
		config = function()
			-- Add completion capabilities
			local capabilities = require('cmp_nvim_lsp').default_capabilities()

			-- Global diagnostic keymaps
			vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open diagnostic float' })
			vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic list' })

			-- Rust
			vim.lsp.config.rust_analyzer = {
				cmd = { 'rust-analyzer' },
				filetypes = { 'rust' },
				root_markers = { 'Cargo.toml' },
				capabilities = capabilities,
				settings = {
					["rust-analyzer"] = {
						cargo = {
							features = "all",
						},
						checkOnSave = {
							enable = true,
						},
						check = {
							command = "clippy",
						},
						imports = {
							group = {
								enable = false,
							},
						},
						completion = {
							postfix = {
								enable = false,
							},
						},
					},
				},
			}
			vim.lsp.enable('rust_analyzer')

			-- Python
			vim.lsp.config.pyright = {
				cmd = { 'pyright-langserver', '--stdio' },
				filetypes = { 'python' },
				root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile' },
				capabilities = capabilities,
				on_init = function(client)
					local root = client.workspace_folders[1].name
					local venv = vim.fs.find({ '.venv', 'venv', 'env', '.env' },
						{ path = root, upward = false })[1]
					if venv then
						client.config.settings.python.pythonPath = vim.fs.joinpath(venv, 'bin',
							'python')
						client.notify('workspace/didChangeConfiguration',
							{ settings = client.config.settings })
					end
				end,
			}
			vim.lsp.enable('pyright')

			-- Java
			vim.lsp.config.jdtls = {
				cmd = { 'jdtls' },
				filetypes = { 'java' },
				root_markers = { 'pom.xml', 'build.gradle', '.git' },
				capabilities = capabilities,
			}
			vim.lsp.enable('jdtls')

			-- SQL keybindings (vim-dadbod-ui handles everything)
			vim.api.nvim_create_autocmd('FileType', {
				pattern = { 'sql', 'mysql', 'plsql' },
				callback = function(args)
					local bufnr = args.buf
					-- Execute SQL query
					vim.keymap.set('n', '<leader>e', '<Cmd>%DB<CR>',
						{ buffer = bufnr, desc = 'Execute SQL file' })
					vim.keymap.set('v', '<leader>e', ':DB<CR>',
						{ buffer = bufnr, desc = 'Execute SQL selection' })
					-- Connect external file to a DBUI database
					vim.keymap.set('n', '<leader>cc', function()
						-- Use the predefined connections from g:dbs
						local dbs = vim.g.dbs or {}
						local names = {}
						for _, db in ipairs(dbs) do
							table.insert(names, db.name)
						end
						vim.ui.select(names, { prompt = 'Select database:' }, function(choice)
							if choice then
								for _, db in ipairs(dbs) do
									if db.name == choice then
										vim.b.db = db.url
										pcall(vim.cmd, 'DBCompletionClearCache')
										print('Connected to: ' .. choice)
										break
									end
								end
							end
						end)
					end, { buffer = bufnr, desc = 'Connect to database' })
				end,
			})
		end
	},

	-- ! More for rust
	{
		'rust-lang/rust.vim',
		ft = { "rust" },
		config = function()
			vim.g.rustfmt_autosave = 1
			vim.g.rustfmt_emit_files = 1
			vim.g.rustfmt_fail_silently = 0
			vim.g.rust_clip_command = 'wl-copy'
		end
	},

	-- Treesitter for better syntax highlighting
	{
		'nvim-treesitter/nvim-treesitter',
		build = ':TSUpdate',
		config = function()
			require('nvim-treesitter.configs').setup({
				ensure_installed = { 'python', 'rust', 'java', 'lua', 'vim', 'vimdoc', 'sql' },
				highlight = { enable = true },
				indent = { enable = true },
			})
		end,
	},

	-- vim-dadbod + completion (loads on SQL filetype)
	{
		'tpope/vim-dadbod',
		ft = { 'sql', 'mysql', 'plsql' },
		init = function()
			-- Define database connections (available before plugin loads)
			vim.g.dbs = {
				{ name = 'northwind', url = 'sqlite:/Users/andersbekkevard/dev/school/db/ex2/database.db' },
				{ name = 'university', url = 'sqlite:/Users/andersbekkevard/dev/school/db/uni_db/database.db' },
				{ name = 'cddb', url = 'sqlite:/Users/andersbekkevard/dev/school/db/tx2/cddb.db' },
			}

			-- Command to select database connection (same as <leader>cc)
			vim.api.nvim_create_user_command('DBSelect', function()
				local dbs = vim.g.dbs or {}
				local names = {}
				for _, db in ipairs(dbs) do
					table.insert(names, db.name)
				end
				vim.ui.select(names, { prompt = 'Select database:' }, function(choice)
					if choice then
						for _, db in ipairs(dbs) do
							if db.name == choice then
								vim.b.db = db.url
								pcall(vim.cmd, 'DBCompletionClearCache')
								print('Connected to: ' .. choice)
								break
							end
						end
					end
				end)
			end, { desc = 'Select database connection for current buffer' })
		end,
	},

	-- vim-dadbod-completion (loads on SQL filetype, sets up cmp)
	{
		'kristijanhusak/vim-dadbod-completion',
		ft = { 'sql', 'mysql', 'plsql' },
		dependencies = { 'tpope/vim-dadbod' },
		config = function()
			vim.api.nvim_create_autocmd('FileType', {
				pattern = { 'sql', 'mysql', 'plsql' },
				callback = function()
					require('cmp').setup.buffer({
						sources = {
							{ name = 'vim-dadbod-completion' },
							{ name = 'buffer' },
						},
					})
				end,
			})
		end,
	},

	-- vim-dadbod-ui (lazy, only loads when you run :DBUI)
	{
		'kristijanhusak/vim-dadbod-ui',
		dependencies = { 'tpope/vim-dadbod' },
		cmd = { 'DBUI', 'DBUIToggle', 'DBUIAddConnection', 'DBUIFindBuffer' },
		init = function()
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.db_ui_execute_on_save = 0
		end,
	},
}
