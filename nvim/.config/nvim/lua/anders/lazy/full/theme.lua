return {
	-------------------------------------------------------------------------------
	--
	-- VS Code theme
	--
	-------------------------------------------------------------------------------
	{
		'Mofiqul/vscode.nvim',
		lazy = false, -- load at start
		priority = 1000, -- load first
		config = function()
			require('vscode').setup({
				-- Enable transparent background
				transparent = true,
				-- Disable italic comment
				italic_comments = false,
				-- Disable nvim-tree background color
				disable_nvimtree_bg = true,
			})
			vim.cmd.colorscheme 'vscode'
		end
	},

	-------------------------------------------------------------------------------
	--
	-- Gruvbox via Base16
	--
	-------------------------------------------------------------------------------
	-- {
	-- 	"wincent/base16-nvim",
	-- 	lazy = false, -- load at start
	-- 	priority = 1000, -- load first
	-- 	config = function()
	-- 		vim.cmd("colorscheme gruvbox-dark-hard")
	-- 		vim.o.background = 'dark'
	-- 		-- XXX: hi Normal ctermbg=NONE
	-- 		-- Make comments more prominent -- they are important.
	-- 		local bools = vim.api.nvim_get_hl(0, { name = 'Boolean' })
	-- 		vim.api.nvim_set_hl(0, 'Comment', bools)
	-- 		-- Make it clearly visible which argument we're at.
	-- 		local marked = vim.api.nvim_get_hl(0, { name = 'PMenu' })
	-- 		vim.api.nvim_set_hl(0, 'LspSignatureActiveParameter',
	-- 			{ fg = marked.fg, bg = marked.bg, ctermfg = marked.ctermfg, ctermbg = marked.ctermbg, bold = true })
	-- 		-- XXX
	-- 		-- Would be nice to customize the highlighting of warnings and the like to make
	-- 		-- them less glaring. But alas
	-- 		-- https://github.com/nvim-lua/lsp_extensions.nvim/issues/21
	-- 		-- call Base16hi("CocHintSign", g:base16_gui03, "", g:base16_cterm03, "", "", "")
	-- 	end
	-- },

	-------------------------------------------------------------------------------
	--
	-- Nice bar at the bottom
	--
	-------------------------------------------------------------------------------
	{
		'itchyny/lightline.vim',
		lazy = false, -- also load at start since it's UI
		config = function()
			-- no need to also show mode in cmd line when we have bar
			vim.o.showmode = false

			-- Custom VS Code Dark-aligned lightline colorscheme
			-- Old default/gruvbox-inherited scheme: colorscheme was unset (lightline default)
			vim.api.nvim_exec([[
				let s:bg      = [ '#1f1f1f', 234 ]
				let s:fg      = [ '#d4d4d4', 188 ]
				let s:left_dk = [ '#252526', 235 ]
				let s:left_md = [ '#373737', 237 ]
				let s:left_lt = [ '#636369', 241 ]
				let s:blue    = [ '#569CD6', 68  ]
				let s:green   = [ '#6A9956', 65  ]
				let s:violet  = [ '#c586c0', 176 ]
				let s:orange  = [ '#ce9178', 173 ]
				let s:red     = [ '#f44747', 196 ]

				" Darker tints for middle/secondary sections per mode
				let s:blue_md   = [ '#3a6a96', 31  ]
				let s:blue_dk   = [ '#2f5577', 24  ]
				let s:green_dk  = [ '#354d2b', 22  ]
				let s:violet_dk = [ '#634360', 53  ]
				let s:red_dk    = [ '#7a2424', 88  ]

				let s:p = {'normal': {}, 'inactive': {}, 'insert': {}, 'replace': {}, 'visual': {}, 'tabline': {}}

				let s:p.normal.left    = [ [ s:bg, s:green ], [ s:fg, s:left_md ] ]
				let s:p.normal.middle  = [ [ s:left_lt, s:left_dk ] ]
				let s:p.normal.right   = [ [ s:bg, s:left_lt ], [ s:fg, s:left_md ] ]

				let s:white = [ '#ffffff', 231 ]
				let s:p.insert.left    = [ [ s:blue, s:white, 'bold' ], [ s:white, s:blue_md ] ]
				let s:p.insert.middle  = [ [ s:fg, s:blue_dk ] ]
				let s:p.insert.right   = [ [ s:white, s:blue_md ], [ s:white, s:blue_dk ] ]

				let s:p.visual.left    = [ [ s:bg, s:violet ], [ s:fg, s:violet_dk ] ]
				let s:p.visual.middle  = [ [ s:fg, s:violet_dk ] ]
				let s:p.visual.right   = [ [ s:bg, s:violet ], [ s:fg, s:violet_dk ] ]

				let s:p.replace.left   = [ [ s:bg, s:red ], [ s:fg, s:red_dk ] ]
				let s:p.replace.middle = [ [ s:fg, s:red_dk ] ]
				let s:p.replace.right  = [ [ s:bg, s:red ], [ s:fg, s:red_dk ] ]

				let s:p.inactive.left   = [ [ s:left_lt, s:left_dk ] ]
				let s:p.inactive.middle = [ [ s:left_lt, s:left_dk ] ]
				let s:p.inactive.right  = [ [ s:left_lt, s:left_dk ] ]

				let s:p.normal.error   = [ [ s:bg, s:red ] ]
				let s:p.normal.warning = [ [ s:bg, s:orange ] ]

				let g:lightline#colorscheme#vscode_dark#palette = lightline#colorscheme#flatten(s:p)
			]], true)

			vim.g.lightline = {
				colorscheme = 'vscode_dark',
				active = {
					left = {
						{ 'mode',     'paste' },
						{ 'readonly', 'filename', 'modified' }
					},
					right = {
						{ 'lineinfo' },
						{ 'percent' },
						{ 'fileencoding', 'filetype' }
					},
				},
				component_function = {
					filename = 'LightlineFilename'
				},
				enable = {
					statusline = 1,
					tabline = 0,
				},
			}
			function LightlineFilenameInLua(opts)
				if vim.fn.expand('%:t') == '' then
					return '[No Name]'
				else
					return vim.fn.getreg('%')
				end
			end

			-- https://github.com/itchyny/lightline.vim/issues/657
			vim.api.nvim_exec(
				[[
					function! g:LightlineFilename()
						return v:lua.LightlineFilenameInLua()
						endfunction
						]],
				true
			)
		end
	},
}
