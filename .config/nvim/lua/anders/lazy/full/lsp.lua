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

			-- SQL (uses global config at ~/.config/sqls/config.yml)
			vim.lsp.config.sqls = {
				cmd = { 'sqls' },
				filetypes = { 'sql', 'mysql' },
				root_markers = { '.sqls', '.git' },
				capabilities = capabilities,
				on_attach = function(client, bufnr)
					local ok, sqls = pcall(require, 'sqls')
					if ok then
						sqls.on_attach(client, bufnr)
					end

					-- Execute SQL query (overrides diagnostic float in SQL files)
					vim.keymap.set({ 'n', 'v' }, '<leader>e', ':SqlsExecuteQuery<CR>',
						{ buffer = bufnr, desc = 'Execute SQL query' })
				end,
			}
			vim.lsp.enable('sqls')
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

	-- sqls.nvim - SQL client extension for sqls LSP
	{
		'nanotee/sqls.nvim',
		lazy = false, -- Load eagerly so it's available when LSP attaches
	},
}
