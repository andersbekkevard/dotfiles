-------------------------------------------------------------------------------
--
-- preferences
--
-------------------------------------------------------------------------------
-- always set leader first!
vim.keymap.set("n", "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "

-- keep more context on screen while scrolling
vim.opt.scrolloff = 10
-- sweet sweet relative line numbers
vim.opt.relativenumber = true
-- and show the absolute line number for the current line
vim.opt.number = true
-- case-insensitive search/replace
vim.opt.ignorecase = true
-- unless uppercase in search term
vim.opt.smartcase = true
-- always draw sign column. prevents buffer moving when adding/deleting sign
vim.opt.signcolumn = 'yes'
-- show a column at 80 characters as a guide for long lines
vim.opt.colorcolumn = '80'
-- except in Rust where the rule is 100 characters
vim.api.nvim_create_autocmd('Filetype', {
	pattern = 'rust',
	callback = function()
		vim.opt.colorcolumn = '100'
	end
})
-- enable mouse mode for resizing panes
vim.o.mouse = "a"

-- tabs: go big or go home (mirroring jon's setup)
vim.opt.shiftwidth = 8
vim.opt.softtabstop = 8
vim.opt.tabstop = 8
vim.opt.expandtab = false

-- Perform a source zshrc
vim.opt.shell = "/bin/zsh"
vim.opt.shellcmdflag = "-i -c"
