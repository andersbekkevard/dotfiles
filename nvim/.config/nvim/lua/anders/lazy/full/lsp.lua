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
					-- Show tables
					vim.keymap.set('n', '<leader>dt', function()
						local db = vim.b.db or ''
						local query
						if db:match('^sqlite') or db:match('%.db$') or db:match('%.sqlite') then
							query = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
						elseif db:match('^mysql') or db:match('^mariadb') then
							query = 'SHOW TABLES;'
						else -- postgres and others
							query = "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
						end
						vim.cmd('DB ' .. query)
					end, { buffer = bufnr, desc = 'Show tables' })

					-- Show schema (prompts for table name)
					vim.keymap.set('n', '<leader>ds', function()
						local db = vim.b.db or ''
						vim.ui.input({ prompt = 'Table name (empty for all): ' }, function(tbl)
							if tbl == nil then return end
							local query
							if db:match('^sqlite') or db:match('%.db$') or db:match('%.sqlite') then
								if tbl == '' then
									query = "SELECT sql FROM sqlite_master WHERE type='table' ORDER BY name;"
								else
									query = "SELECT sql FROM sqlite_master WHERE name='" .. tbl .. "';"
								end
							elseif db:match('^mysql') or db:match('^mariadb') then
								if tbl == '' then
									query = 'SHOW TABLES;'
								else
									query = 'DESCRIBE ' .. tbl .. ';'
								end
							else -- postgres
								if tbl == '' then
									query = "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name, ordinal_position;"
								else
									query = "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name='" .. tbl .. "' ORDER BY ordinal_position;"
								end
							end
							vim.cmd('DB ' .. query)
						end)
					end, { buffer = bufnr, desc = 'Show schema' })

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
			-- Auto-discover SQLite databases from cwd
			local function discover_dbs()
				local dbs = {}
				local seen = {}
				local cwd = vim.fn.getcwd()
				local function is_db_file(name)
					return name:match('%.db$') or name:match('%.sqlite$') or name:match('%.sqlite3$')
				end
				local function scan(dir, depth)
					if depth > 3 then return end
					local h = vim.uv.fs_scandir(dir)
					if not h then return end
					while true do
						local name, typ = vim.uv.fs_scandir_next(h)
						if not name then break end
						local full = dir .. '/' .. name
						if typ == 'directory' and not name:match('^%.') then
							scan(full, depth + 1)
						elseif typ == 'file' and is_db_file(name) then
							if not seen[full] then
								seen[full] = true
								local label = name:gsub('%.db$', ''):gsub('%.sqlite3?$', '')
								table.insert(dbs, { name = label, url = 'sqlite:' .. full })
							end
						end
					end
				end
				scan(cwd, 0)
				return dbs
			end

			-- Also support .dadbod.json in project root for custom connections
			local function load_project_dbs()
				local path = vim.fn.getcwd() .. '/.dadbod.json'
				local f = io.open(path, 'r')
				if not f then return {} end
				local content = f:read('*a')
				f:close()
				local ok, parsed = pcall(vim.json.decode, content)
				if ok and type(parsed) == 'table' then return parsed end
				return {}
			end

			local function refresh_dbs()
				local dbs = load_project_dbs()
				vim.list_extend(dbs, discover_dbs())
				vim.g.dbs = dbs
				return dbs
			end

			refresh_dbs()

			vim.api.nvim_create_user_command('DBRefresh', function()
				local dbs = refresh_dbs()
				print('Found ' .. #dbs .. ' database(s)')
			end, { desc = 'Re-scan for databases' })

			vim.api.nvim_create_user_command('DBSelect', function()
				local dbs = refresh_dbs()
				if #dbs == 0 then
					print('No databases found in ' .. vim.fn.getcwd())
					return
				end
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
