return {
	-------------------------------------------------------------------------------
	--
	-- GitHub Copilot inline suggestions
	--
	-------------------------------------------------------------------------------
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		keys = {
			{
				"<leader>cp",
				function()
					local client = require("copilot.client")
					local command = require("copilot.command")
					local state

					if client.is_disabled() then
						command.enable()
						state = "enabled"
					else
						command.disable()
						state = "disabled"
					end

					vim.api.nvim_echo({ { "Copilot: " .. state, "Normal" } }, false, {})
				end,
				desc = "Toggle Copilot",
			},
		},
		dependencies = {
			"hrsh7th/nvim-cmp",
		},
		opts = {
			panel = {
				enabled = false,
			},
			suggestion = {
				enabled = true,
				auto_trigger = true,
				hide_during_completion = false,
				debounce = 30,
				keymap = {
					accept = false,
					accept_word = "<M-Tab>",
					accept_line = false,
					next = "<M-]>",
					prev = "<M-[>",
					dismiss = "<C-]>",
				},
			},
		},
	},
}
