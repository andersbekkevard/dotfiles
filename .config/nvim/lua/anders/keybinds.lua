-------------------------------------------------------------------------------
--
-- Core Keybinds (loaded immediately, not as a plugin)
--
-------------------------------------------------------------------------------

-- quick-save
vim.keymap.set('n', '<leader>w', '<cmd>w<cr>')
vim.keymap.set('n', '<leader>x', '<cmd>bd<cr>', { desc = 'Close buffer' })

-- Jump to start and end of line using the home row keys
vim.keymap.set('', 'H', '^')
vim.keymap.set('', 'L', '$')

-- greatest remap ever (modified)
vim.keymap.set("x", "p", [["_dP]])

-- next greatest remap ever : asbjornHaland
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

-- Delete to system clipboard
vim.keymap.set({ "n", "v" }, "<leader>d", [["+d]])
vim.keymap.set("n", "<leader>D", [["+D]])

-- Paste from system clipboard after cursor/ replace selection
vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]])
-- Paste from system clipboard before cursor / replace selection
vim.keymap.set({ "n", "v" }, "<leader>P", [["+P]])

-- handy keymap for replacing up to next _ (like in variable names)
vim.keymap.set('n', '<leader>m', 'ct_')
-- handy keymap for replacing up to previous _ (like in variable names)
vim.keymap.set('n', '<leader>M', 'cT_')

-- always center search results
vim.keymap.set('n', 'n', 'nzz', { silent = true })
vim.keymap.set('n', 'N', 'Nzz', { silent = true })

-- Remap to center on vertical jump
vim.keymap.set('n', '<C-u>', "<C-u>zz")
vim.keymap.set('n', '<C-d>', "<C-d>zz")

-- Smart j and k: move by visual line only when lines are wrapped
-- In normal mode with no count, use gj/gk; with count, use regular j/k
vim.keymap.set('n', 'j', function()
	return vim.v.count == 0 and 'gj' or 'j'
end, { expr = true, silent = true, desc = 'Move down (visual line if wrapped)' })

vim.keymap.set('n', 'k', function()
	return vim.v.count == 0 and 'gk' or 'k'
end, { expr = true, silent = true, desc = 'Move up (visual line if wrapped)' })

-- Visual mode: always use gj/gk for consistency
vim.keymap.set('v', 'j', 'gj', { silent = true })
vim.keymap.set('v', 'k', 'gk', { silent = true })

-- Toggle comment on current line with uppercase Q
vim.keymap.set('n', 'Q', 'gcc', { remap = true })

-- Make escape undo search highlight without saving
vim.keymap.set('n', '<Esc>', '<cmd>noh<CR><Esc>', { silent = true })
-- Normal escape functionality from insert mode
vim.keymap.set('i', '<Esc>', '<Esc>', { silent = true })

-- More granularity in undoblocks
vim.keymap.set("i", "<Space>", "<Space><C-g>u")
vim.keymap.set("i", ".", ".<C-g>u")
vim.keymap.set("i", ",", ",<C-g>u")
vim.keymap.set("i", ";", ";<C-g>u")
vim.keymap.set("i", ":", ":<C-g>u")
vim.keymap.set("i", "!", "!<C-g>u")
vim.keymap.set("i", "?", "?<C-g>u")

-- "inside file" text object - select entire buffer content
-- Works with any operator: dif (delete), yif (yank), cif (change), vif (visual), etc.
vim.keymap.set({ 'o', 'x' }, 'if', ':<C-u>normal! ggVG<CR>', { silent = true, desc = 'inside file' })

-- Neovim-only keybinds
if not vim.g.vscode then
	-- Replace word under cursor with substitution pattern
	vim.keymap.set("n", "<leader>r", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

	-- LazyGit
	vim.keymap.set('n', '<leader>lg', ":LazyGit<enter>", { desc = '[L]azy [G]it' })

	-- Window navigation handled by vim-tmux-navigator plugin (C-h/j/k/l)

	-- Resize splits with Ctrl + arrow keys
	vim.keymap.set('n', '<C-Up>', ':resize +1<CR>', { desc = 'Increase window height' })
	vim.keymap.set('n', '<C-Down>', ':resize -1<CR>', { desc = 'Decrease window height' })
	vim.keymap.set('n', '<C-Left>', ':vertical resize -1<CR>', { desc = 'Decrease window width' })
	vim.keymap.set('n', '<C-Right>', ':vertical resize +1<CR>', { desc = 'Increase window width' })

	-- Move splits to different positions with Ctrl + Shift + hjkl
	vim.keymap.set('n', '<C-S-h>', '<C-w>H', { desc = 'Move window to far left' })
	vim.keymap.set('n', '<C-S-j>', '<C-w>J', { desc = 'Move window to bottom' })
	vim.keymap.set('n', '<C-S-k>', '<C-w>K', { desc = 'Move window to top' })
	vim.keymap.set('n', '<C-S-l>', '<C-w>L', { desc = 'Move window to far right' })

	-- Move splits with Ctrl + Shift + arrow keys
	vim.keymap.set('n', '<C-S-Left>', '<C-w>H', { desc = 'Move window to far left' })
	vim.keymap.set('n', '<C-S-Down>', '<C-w>J', { desc = 'Move window to bottom' })
	vim.keymap.set('n', '<C-S-Up>', '<C-w>K', { desc = 'Move window to top' })
	vim.keymap.set('n', '<C-S-Right>', '<C-w>L', { desc = 'Move window to far right' })

	-- Create splits
	vim.keymap.set('n', '<C-s>', '<C-w>v', { desc = 'Split vertically' })
	vim.keymap.set('n', '<C-S-s>', '<C-w>s', { desc = 'Split horizontally' })

	-- Buffer navigation (like Jon's setup)
	-- <leader><leader> toggles between current and previous buffer
	vim.keymap.set('n', '<leader><leader>', '<c-^>', { desc = 'Toggle between buffers' })
	-- + and 0 for sequential buffer navigation
	vim.keymap.set('n', '+', ':bn<cr>', { desc = 'Next buffer (right)' })
	vim.keymap.set('n', '0', ':bp<cr>', { desc = 'Previous buffer (left)' })
end
