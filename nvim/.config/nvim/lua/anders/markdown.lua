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

local function rendered_table_at_cursor()
	local ok_parser, parser = pcall(require, "markdown-table-wrap.parser")
	local ok_inline, inline = pcall(require, "markdown-table-wrap.inline")
	if not ok_parser or not ok_inline then
		return nil
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local table_info = parser.parse_at_cursor(bufnr, row)
	if not table_info then
		return nil
	end

	local marks = vim.api.nvim_buf_get_extmarks(
		bufnr,
		inline.namespace(),
		{ table_info.start_lnum - 1, 0 },
		{ table_info.end_lnum, 0 },
		{ details = true }
	)
	local rendered = false
	local signature = {}
	for _, mark in ipairs(marks) do
		local virtual_text = mark[4].virt_text
		if virtual_text then
			rendered = true
			for _, chunk in ipairs(virtual_text) do
				table.insert(signature, chunk[1])
			end
		end
	end

	if not rendered then
		return nil
	end
	return table_info, inline, table.concat(signature, "\n")
end

local function move_to_buffer_line(row)
	local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
	local column = math.min(vim.api.nvim_win_get_cursor(0)[2], #line)
	vim.api.nvim_win_set_cursor(0, { row, column })
end

local function table_visual_step(direction)
	local table_info, inline, before = rendered_table_at_cursor()
	if not table_info then
		return false
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local edge = direction > 0 and table_info.end_lnum or table_info.start_lnum
	if row ~= edge then
		move_to_buffer_line(row + direction)
		return true
	end

	if not inline.scroll(0, direction) then
		return false
	end
	local _, _, after = rendered_table_at_cursor()
	return after ~= before
end

function M.table_visual_motion(direction)
	for _ = 1, vim.v.count1 do
		if not table_visual_step(direction) then
			vim.cmd("normal! " .. (direction > 0 and "gj" or "gk"))
		end
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
		M.table_visual_motion(1)
	end, {
		buffer = bufnr,
		silent = true,
		desc = "Move down by visual Markdown row",
	})
	vim.keymap.set("n", "k", function()
		M.table_visual_motion(-1)
	end, {
		buffer = bufnr,
		silent = true,
		desc = "Move up by visual Markdown row",
	})
end

return M
