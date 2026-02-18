-------------------------------------------------------------------------------
--
-- preferences
--
-------------------------------------------------------------------------------
-- always set leader first!
vim.keymap.set("n", "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "

-- enable true color support
vim.opt.termguicolors = true

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
-- enable mouse mode for resizing panes
vim.o.mouse = "a"
-- keep buffers open in the background when navigating away
vim.o.hidden = true

-- tabs: go big or go home (mirroring jon's setup)
vim.opt.shiftwidth = 8
vim.opt.softtabstop = 8
vim.opt.tabstop = 8
vim.opt.expandtab = false

-- Perform a source zshrc
vim.opt.shell = "/bin/zsh"
vim.opt.shellcmdflag = "-i -c"
