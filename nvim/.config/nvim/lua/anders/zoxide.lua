local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local utils = require("telescope.utils")

local home = vim.env.HOME
local M = {}

function M.list()
	local results = utils.get_os_command_output({ "zoxide", "query", "-ls" })

	local entries = {}
	for _, line in ipairs(results) do
		local score, path = line:match("^%s*([%d.]+)%s+(.+)$")
		if path then
			table.insert(entries, {
				path = path,
				z_score = tonumber(score) or 0,
			})
		end
	end

	pickers.new({}, {
		prompt_title = "Zoxide",
		finder = finders.new_table({
			results = entries,
			entry_maker = function(entry)
				local display = entry.path:gsub("^" .. vim.pesc(home), "~")
				return {
					value = entry.path,
					ordinal = entry.path,
					display = display,
					path = entry.path,
					z_score = entry.z_score,
				}
			end,
		}),
		sorter = sorters.Sorter:new({
			highlighter = function(_, prompt, display)
				local highlights = {}
				if prompt == "" then return highlights end
				local display_lower = display:lower()
				for token in prompt:lower():gmatch("%S+") do
					local start = 1
					while true do
						local s, e = display_lower:find(token, start, true)
						if not s then break end
						for i = s, e do
							table.insert(highlights, { start = i, finish = i })
						end
						start = e + 1
					end
				end
				return highlights
			end,
			scoring_function = function(_, prompt, _, entry)
				if prompt == "" then return 1 end
				local ordinal = entry.ordinal:lower()
				for token in prompt:lower():gmatch("%S+") do
					if not ordinal:find(token, 1, true) then
						return -1
					end
				end
				return 1
			end,
		}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				vim.cmd.cd(selection.path)
				require("oil").open(selection.path)
			end)
			return true
		end,
	}):find()
end

return M
