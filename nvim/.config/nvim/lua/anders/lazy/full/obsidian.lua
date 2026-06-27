local obsidian_jump_stack = {}

local function push_obsidian_jump()
	local name = vim.api.nvim_buf_get_name(0)
	if name == "" then
		return
	end

	table.insert(obsidian_jump_stack, {
		name = name,
		cursor = vim.api.nvim_win_get_cursor(0),
	})
end

local function pop_obsidian_jump()
	local jump = table.remove(obsidian_jump_stack)
	if not jump then
		vim.notify("No Obsidian jump to go back to", vim.log.levels.INFO)
		return
	end

	vim.cmd.edit(vim.fn.fnameescape(jump.name))
	pcall(vim.api.nvim_win_set_cursor, 0, jump.cursor)
end

local function remove_checked_checkbox_marker()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
	if not line then
		return false
	end

	local indent, body = line:match("^(%s*)[-+*]%s+%[[xX]%]%s*(.*)$")
	if not indent then
		indent, body = line:match("^(%s*)%d+[.)]%s+%[[xX]%]%s*(.*)$")
	end
	if not indent then
		return false
	end

	vim.api.nvim_buf_set_lines(0, row - 1, row, true, { indent .. body })
	return true
end

local function feedkeys(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", true)
end

local function obsidian_smart_action()
	local api = require("obsidian.api")
	if api.cursor_link() or api.cursor_tag() or api.cursor_heading() then
		feedkeys(api.smart_action())
		return
	end
	if remove_checked_checkbox_marker() then
		return
	end
	feedkeys(api.smart_action())
end

return {
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*",
		event = { "BufReadPre *.md", "BufNewFile *.md" },
		cond = function()
			return vim.fn.isdirectory(vim.fn.expand("~/vault")) == 1
		end,
		opts = {
			legacy_commands = false,
			workspaces = {
				{
					name = "vault",
					path = "~/vault",
				},
			},
			picker = {
				name = "telescope.nvim",
			},
			link = {
				style = "wiki",
				format = "shortest",
			},
			ui = {
				enable = false,
			},
			backlinks = {
				parse_headers = false,
			},
			checkbox = {
				create_new = true,
				order = { " ", "x", "" },
			},
			callbacks = {
				enter_note = function()
					local api = require("obsidian.api")
					local actions = require("obsidian.actions")
					local map = function(lhs, rhs, desc)
						vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
					end

					map("gf", function()
						if api.cursor_link() then
							push_obsidian_jump()
						end
						actions.follow_link()
					end, "Follow Obsidian link")
					map("gb", pop_obsidian_jump, "Go back from Obsidian link")
					map("<leader>os", "<cmd>Obsidian search<cr>", "Search Obsidian notes")
					map("<leader>ob", "<cmd>Obsidian backlinks<cr>", "Obsidian backlinks")
					map("<leader>ol", "<cmd>Obsidian links<cr>", "Obsidian outgoing links")
					map("<leader>on", "<cmd>Obsidian new<cr>", "New Obsidian note")
					map("<leader>oo", "<cmd>Obsidian open<cr>", "Open note in Obsidian")
					vim.keymap.set("n", "<CR>", obsidian_smart_action, {
						buffer = true,
						desc = "Obsidian Smart Action",
					})
				end,
			},
		},
	},
}
