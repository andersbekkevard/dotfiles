local M = {}

local function current_line()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	return vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
end

function M.is_markdown_file(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr or 0):lower()
	return name:match("%.md$") ~= nil
end

function M.is_heading(line)
	return line:match("^%s*#%s+") ~= nil or line:match("^%s*##+%s+") ~= nil
end

function M.toggle_heading_fold()
	if not M.is_markdown_file(0) then
		return false
	end
	if not M.is_heading(current_line()) then
		return false
	end

	vim.cmd("normal! za")
	return true
end

function M.feed_normal_enter()
	vim.cmd("normal! \r")
end

function M.foldtext()
	local line = vim.fn.getline(vim.v.foldstart)
	local level = line:match("^%s*(#+)%s+") or ""
	local hidden_lines = vim.v.foldend - vim.v.foldstart
	local suffix = string.format("  [%d line%s folded]", hidden_lines, hidden_lines == 1 and "" or "s")
	local heading_hl = "RenderMarkdownH" .. math.min(#level, 6)

	return {
		{ line, heading_hl },
		{ suffix, "Comment" },
	}
end

function M.fold_all()
	if M.is_markdown_file(0) then
		vim.cmd("normal! zM")
	end
end

function M.unfold_all()
	if M.is_markdown_file(0) then
		vim.cmd("normal! zR")
	end
end

function M.setup_buffer(bufnr)
	if not M.is_markdown_file(bufnr) then
		return
	end

	vim.wo.foldmethod = "expr"
	vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
	vim.wo.foldtext = "v:lua.require'anders.markdown'.foldtext()"
	vim.wo.foldlevel = 99
	vim.o.foldlevelstart = 99
	vim.wo.foldenable = true
	vim.wo.foldcolumn = "0"
	vim.opt_local.fillchars:append({
		fold = " ",
	})

	vim.keymap.set("n", "<CR>", function()
		if not M.toggle_heading_fold() then
			M.feed_normal_enter()
		end
	end, {
		buffer = bufnr,
		desc = "Toggle Markdown heading fold",
	})
	vim.keymap.set("n", "<leader>mf", M.fold_all, {
		buffer = bufnr,
		desc = "Fold all Markdown headings",
	})
	vim.keymap.set("n", "<leader>mu", M.unfold_all, {
		buffer = bufnr,
		desc = "Unfold all Markdown headings",
	})
	vim.keymap.set("n", "j", function()
		require("anders.table_lens").motion(1)
	end, {
		buffer = bufnr,
		silent = true,
		desc = "Move down by visual Markdown row",
	})
	vim.keymap.set("n", "k", function()
		require("anders.table_lens").motion(-1)
	end, {
		buffer = bufnr,
		silent = true,
		desc = "Move up by visual Markdown row",
	})
	require("anders.table_lens").attach(bufnr)
end

return M
