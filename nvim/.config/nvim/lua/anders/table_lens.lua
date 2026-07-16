local M = {}

local namespace = vim.api.nvim_create_namespace("anders-markdown-table-lens")
local active = nil

local border_chars = {
	["╭"] = true,
	["╮"] = true,
	["╰"] = true,
	["╯"] = true,
	["┌"] = true,
	["┐"] = true,
	["└"] = true,
	["┘"] = true,
	["┬"] = true,
	["┴"] = true,
	["├"] = true,
	["┤"] = true,
	["┼"] = true,
	["│"] = true,
	["─"] = true,
}

local function iter_chars(text)
	local index = 1
	return function()
		if index > #text then
			return nil
		end
		local start_col, end_col, char = text:find("([%z\1-\127\194-\244][\128-\191]*)", index)
		if not start_col then
			return nil
		end
		index = end_col + 1
		return char, start_col, end_col
	end
end

local function plugin_parts()
	local ok_plugin, plugin = pcall(require, "markdown-table-wrap")
	local ok_parser, parser = pcall(require, "markdown-table-wrap.parser")
	local ok_render, render = pcall(require, "markdown-table-wrap.render")
	local ok_nav, nav = pcall(require, "markdown-table-wrap.nav")
	local ok_markdown, markdown = pcall(require, "markdown-table-wrap.markdown")
	if not (ok_plugin and ok_parser and ok_render and ok_nav and ok_markdown and plugin.config) then
		return nil
	end
	return {
		plugin = plugin,
		config = plugin.config,
		parser = parser,
		render = render,
		nav = nav,
		markdown = markdown,
	}
end

local function source_cell(table_info, group, column)
	if group == 1 then
		return table_info.header[column]
	end
	local row = table_info.rows[group - 1]
	return row and row[column] or nil
end

local function source_lnum(table_info, group)
	if group == 1 then
		return table_info.start_lnum
	end
	return table_info.start_lnum + group
end

local function trim_rendered_cell(text)
	local leading = text:match("^%s*") or ""
	local trailing = text:match("%s*$") or ""
	local first = #leading + 1
	local last = #text - #trailing
	if first > last then
		return "", #leading
	end
	return text:sub(first, last), #leading
end

local function rendered_borders(line)
	local result = {}
	for char, start_col, end_col in iter_chars(line) do
		if char == "│" then
			table.insert(result, { start_col = start_col, end_col = end_col })
		end
	end
	return result
end

local function map_display_to_source(raw, display, target)
	if raw == "" then
		return 0
	end
	if raw == display then
		return math.min(target, #raw)
	end

	local raw_index = 1
	local best = 0
	for char, display_start in iter_chars(display) do
		local found = raw:find(char, raw_index, true)
		if found then
			if display_start - 1 <= target then
				best = found - 1
			end
			raw_index = found + #char
		elseif display_start - 1 > target then
			break
		end
	end
	return math.min(best, #raw)
end

local function build_rows(source_buf, table_info, rendered, parts)
	local rows = {}
	local group = 0
	local in_group = false
	local segment = 0
	local display_search = {}

	for lens_lnum, line in ipairs(rendered.lines) do
		local borders = rendered_borders(line)
		if #borders >= 2 then
			if not in_group then
				group = group + 1
				segment = 0
				in_group = true
				display_search[group] = {}
			end
			segment = segment + 1

			local lnum = source_lnum(table_info, group)
			local source_line = vim.api.nvim_buf_get_lines(source_buf, lnum - 1, lnum, false)[1] or ""
			local spans = parts.nav.spans(source_line)
			local cells = {}

			for column = 1, math.min(#spans, #borders - 1) do
				local left = borders[column]
				local right = borders[column + 1]
				local rendered_cell = line:sub(left.end_col + 1, right.start_col - 1)
				local visible, leading = trim_rendered_cell(rendered_cell)
				local parsed = source_cell(table_info, group, column) or { text = "", spans = {} }
				local display = parts.markdown.apply_link_icons(parsed, parts.config).text or ""
				local search_from = display_search[group][column] or 1
				local found = visible ~= "" and display:find(visible, search_from, true) or search_from
				if not found then
					found = search_from
				end
				display_search[group][column] = math.min(#display + 1, found + #visible)

				local span = spans[column]
				local raw = source_line:sub(span.start_col + 1, span.end_col)
				local segment_source_col = span.start_col
					+ map_display_to_source(raw, display, math.max(0, found - 1))
				table.insert(cells, {
					column = column,
					lens_start_col = left.end_col,
					lens_end_col = right.start_col - 2,
					content_start_col = left.end_col + leading,
					display_start = found - 1,
					display = display,
					raw = raw,
					source_start_col = span.start_col,
					source_end_col = span.end_col,
					segment_source_col = segment_source_col,
				})
			end

			rows[lens_lnum] = {
				source_lnum = lnum,
				group = group,
				segment = segment,
				cells = cells,
			}
		else
			in_group = false
		end
	end

	return rows
end

local function highlight_lens(bufnr, rendered, config)
	require("markdown-table-wrap.theme").apply(config)
	vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

	for index, line_object in ipairs(rendered.line_objects or {}) do
		local line = line_object.text or rendered.lines[index]
		local row = index - 1
		vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
			end_row = row,
			end_col = #line,
			hl_group = index == 2 and "MarkdownTableWrapHeader" or "MarkdownTableWrapInline",
			priority = 10,
		})

		for char, start_col, end_col in iter_chars(line) do
			if border_chars[char] then
				vim.api.nvim_buf_set_extmark(bufnr, namespace, row, start_col - 1, {
					end_row = row,
					end_col = end_col,
					hl_group = "MarkdownTableWrapBorder",
					priority = 20,
				})
			end
		end

		for _, chunk in ipairs(line_object.chunks or {}) do
			vim.api.nvim_buf_set_extmark(bufnr, namespace, row, chunk.start_col, {
				end_row = row,
				end_col = chunk.end_col,
				hl_group = chunk.hl_group,
				priority = 30,
			})
		end
	end
end

local function save_window_options(winid)
	return {
		cursorline = vim.wo[winid].cursorline,
		foldenable = vim.wo[winid].foldenable,
		foldcolumn = vim.wo[winid].foldcolumn,
		list = vim.wo[winid].list,
		number = vim.wo[winid].number,
		relativenumber = vim.wo[winid].relativenumber,
		signcolumn = vim.wo[winid].signcolumn,
		wrap = vim.wo[winid].wrap,
	}
end

local function apply_lens_window_options(winid)
	vim.wo[winid].cursorline = true
	vim.wo[winid].foldenable = false
	vim.wo[winid].foldcolumn = "0"
	vim.wo[winid].list = false
	vim.wo[winid].number = true
	vim.wo[winid].relativenumber = true
	vim.wo[winid].signcolumn = "no"
	vim.wo[winid].wrap = false
end

local function restore_window_options(session)
	if not vim.api.nvim_win_is_valid(session.winid) then
		return
	end
	for option, value in pairs(session.window_options) do
		vim.wo[session.winid][option] = value
	end
end

local function cell_at(row, column)
	if not row then
		return nil
	end
	for _, cell in ipairs(row.cells) do
		if column >= cell.lens_start_col and column <= cell.lens_end_col then
			return cell
		end
	end
	local nearest = nil
	local distance = math.huge
	for _, cell in ipairs(row.cells) do
		local current = math.min(math.abs(column - cell.lens_start_col), math.abs(column - cell.lens_end_col))
		if current < distance then
			nearest = cell
			distance = current
		end
	end
	return nearest
end

local function editable_at(session, lens_lnum, column)
	local row = session.rows[lens_lnum]
	if row then
		return row, cell_at(row, column), lens_lnum
	end

	for distance = 1, #session.rendered.lines do
		for _, candidate in ipairs({ lens_lnum + distance, lens_lnum - distance }) do
			row = session.rows[candidate]
			if row then
				return row, cell_at(row, column), candidate
			end
		end
	end
	return nil
end

local function source_position(row, cell, lens_column, key)
	if key == "I" then
		return cell.source_start_col, "i"
	elseif key == "A" then
		return math.max(cell.source_start_col, cell.source_end_col - 1), "a"
	end

	local within = math.max(0, lens_column - cell.content_start_col)
	local display_offset = math.min(#cell.display, cell.display_start + within)
	local raw_offset = map_display_to_source(cell.raw, cell.display, display_offset)
	return math.min(cell.source_end_col, cell.source_start_col + raw_offset), key
end

local function delete_lens(session)
	if session.lens_buf and vim.api.nvim_buf_is_valid(session.lens_buf) then
		vim.api.nvim_buf_delete(session.lens_buf, { force = true })
	end
end

local function leave_lens(target_lnum)
	local session = active
	if not session then
		return
	end
	active = nil

	if vim.api.nvim_win_is_valid(session.winid) and vim.api.nvim_buf_is_valid(session.source_buf) then
		vim.api.nvim_win_set_buf(session.winid, session.source_buf)
		restore_window_options(session)
		local total = vim.api.nvim_buf_line_count(session.source_buf)
		target_lnum = math.max(1, math.min(target_lnum or session.table_info.start_lnum, total))
		vim.api.nvim_win_set_cursor(session.winid, { target_lnum, 0 })
	end
	delete_lens(session)
end

local function focus_rendered_source(session, source_row, source_column)
	local best_lnum = nil
	local best_cell = nil
	local best_distance = math.huge
	for lnum, row in pairs(session.rows) do
		if row.source_lnum == source_row then
			for _, cell in ipairs(row.cells) do
				local distance = math.abs(source_column - cell.segment_source_col)
				if distance < best_distance then
					best_lnum = lnum
					best_cell = cell
					best_distance = distance
				end
			end
		end
	end
	if best_lnum and best_cell then
		vim.api.nvim_win_set_cursor(session.winid, { best_lnum, best_cell.content_start_col })
	end
end

local function render_session(session, focus)
	local parts = plugin_parts()
	if not parts or not vim.api.nvim_buf_is_valid(session.source_buf) then
		return false
	end

	local table_info = parts.parser.parse_at_cursor(session.source_buf, focus.source_lnum)
	if not table_info then
		return false
	end
	local rendered = parts.render.render_table(table_info, parts.config)
	session.table_info = table_info
	session.rendered = rendered
	session.rows = build_rows(session.source_buf, table_info, rendered, parts)

	vim.bo[session.lens_buf].modifiable = true
	vim.api.nvim_buf_set_lines(session.lens_buf, 0, -1, false, rendered.lines)
	vim.bo[session.lens_buf].modifiable = false
	highlight_lens(session.lens_buf, rendered, parts.config)
	vim.api.nvim_win_set_buf(session.winid, session.lens_buf)
	apply_lens_window_options(session.winid)
	focus_rendered_source(session, focus.source_lnum, focus.source_col)
	return true
end

local function begin_edit(key)
	local session = active
	if not session or not vim.api.nvim_win_is_valid(session.winid) then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(session.winid)
	local row, cell = editable_at(session, cursor[1], cursor[2])
	if not row or not cell then
		return
	end

	local source_col, insert_key = source_position(row, cell, cursor[2], key)
	session.editing = true
	session.edit_focus = { source_lnum = row.source_lnum, source_col = source_col }
	vim.api.nvim_win_set_buf(session.winid, session.source_buf)
	restore_window_options(session)
	vim.api.nvim_win_set_cursor(session.winid, { row.source_lnum, source_col })

	vim.api.nvim_create_autocmd("InsertLeave", {
		buffer = session.source_buf,
		once = true,
		callback = function()
			vim.schedule(function()
				if active ~= session then
					return
				end
				session.editing = false
				local focus = {
					source_lnum = vim.api.nvim_win_get_cursor(session.winid)[1],
					source_col = vim.api.nvim_win_get_cursor(session.winid)[2],
				}
				if not render_session(session, focus) then
					active = nil
					delete_lens(session)
					vim.notify("Markdown table is no longer valid; staying in the source buffer.", vim.log.levels.WARN)
				end
			end)
		end,
	})

	vim.schedule(function()
		vim.api.nvim_feedkeys(vim.keycode(insert_key), "n", false)
	end)
end

local function lens_motion(direction)
	local session = active
	if not session then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(session.winid)
	local target = cursor[1] + (direction * vim.v.count1)
	if target < 1 then
		leave_lens(session.table_info.start_lnum - 1)
	elseif target > #session.rendered.lines then
		leave_lens(session.table_info.end_lnum + 1)
	else
		vim.api.nvim_win_set_cursor(session.winid, { target, cursor[2] })
	end
end

local function write_source(session)
	if not vim.api.nvim_buf_is_valid(session.source_buf) then
		error("Cannot write Markdown table: the source buffer no longer exists")
	end

	vim.api.nvim_buf_call(session.source_buf, function()
		vim.cmd("write")
	end)
	vim.bo[session.lens_buf].modified = false
end

local function configure_lens_buffer(session)
	local buf = session.lens_buf
	local source_name = vim.api.nvim_buf_get_name(session.source_buf)
	local lens_name = source_name ~= "" and source_name or ("buffer/" .. session.source_buf)
	vim.api.nvim_buf_set_name(buf, "table-lens://" .. lens_name)
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown-table-lens"
	vim.bo[buf].modifiable = false
	vim.bo[buf].undolevels = -1

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			write_source(session)
		end,
	})
	vim.api.nvim_create_autocmd("BufHidden", {
		buffer = buf,
		callback = function()
			if active ~= session or session.editing then
				return
			end
			active = nil
			vim.schedule(function()
				delete_lens(session)
			end)
		end,
	})

	for _, key in ipairs({ "i", "a", "I", "A" }) do
		vim.keymap.set("n", key, function()
			begin_edit(key)
		end, { buffer = buf, silent = true, nowait = true, desc = "Edit source Markdown table cell" })
	end
	vim.keymap.set("n", "j", function()
		lens_motion(1)
	end, { buffer = buf, silent = true, desc = "Move down in Markdown table lens" })
	vim.keymap.set("n", "k", function()
		lens_motion(-1)
	end, { buffer = buf, silent = true, desc = "Move up in Markdown table lens" })
	vim.keymap.set("n", "q", function()
		leave_lens(session.table_info.start_lnum - 1)
	end, { buffer = buf, silent = true, nowait = true, desc = "Close Markdown table lens" })
	vim.keymap.set("n", "<Esc>", function()
		leave_lens(session.table_info.start_lnum - 1)
	end, { buffer = buf, silent = true, nowait = true, desc = "Close Markdown table lens" })
end

local function open(source_buf, source_row, direction)
	if active or not vim.api.nvim_buf_is_valid(source_buf) then
		return false
	end
	local parts = plugin_parts()
	if not parts then
		return false
	end
	if parts.plugin.state.paused_buffers[source_buf] then
		return false
	end
	local table_info = parts.parser.parse_at_cursor(source_buf, source_row)
	if not table_info then
		return false
	end

	local winid = vim.api.nvim_get_current_win()
	local lens_buf = vim.api.nvim_create_buf(false, true)
	local source_col = vim.api.nvim_win_get_cursor(winid)[2]
	local session = {
		source_buf = source_buf,
		winid = winid,
		lens_buf = lens_buf,
		window_options = save_window_options(winid),
		table_info = table_info,
	}
	active = session
	configure_lens_buffer(session)
	if not render_session(session, { source_lnum = source_row, source_col = source_col }) then
		active = nil
		delete_lens(session)
		return false
	end

	local editable = {}
	for lnum in pairs(session.rows) do
		table.insert(editable, lnum)
	end
	table.sort(editable)
	if direction and #editable > 0 then
		local target = direction > 0 and editable[1] or editable[#editable]
		vim.api.nvim_win_set_cursor(winid, { target, 0 })
	end
	return true
end

function M.motion(direction)
	local bufnr = vim.api.nvim_get_current_buf()
	for _ = 1, vim.v.count1 do
		vim.cmd("normal! " .. (direction > 0 and "gj" or "gk"))
		local row = vim.api.nvim_win_get_cursor(0)[1]
		if open(bufnr, row, direction) then
			return
		end
	end
end

function M.toggle()
	local source_buf = active and active.source_buf or vim.api.nvim_get_current_buf()
	local parts = plugin_parts()
	if not parts or not vim.api.nvim_buf_is_valid(source_buf) then
		return
	end

	local enabled = parts.plugin.state.paused_buffers[source_buf] ~= true
	if active and active.source_buf == source_buf then
		leave_lens(active.table_info.start_lnum)
	end

	vim.api.nvim_buf_call(source_buf, function()
		if enabled then
			parts.plugin.disable_auto_preview()
		else
			parts.plugin.enable_auto_preview()
		end
	end)

	vim.notify("Visual Markdown tables " .. (enabled and "disabled" or "enabled"))
end

function M.attach(bufnr)
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = bufnr,
		callback = function()
			if active or vim.api.nvim_get_current_buf() ~= bufnr or vim.api.nvim_get_mode().mode ~= "n" then
				return
			end
			open(bufnr, vim.api.nvim_win_get_cursor(0)[1])
		end,
	})
end

return M
