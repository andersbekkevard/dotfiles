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
				hide_during_completion = true,
				keymap = {
					accept = "<M-l>",
					next = "<M-]>",
					prev = "<M-[>",
					dismiss = "<C-]>",
				},
			},
		},
		config = function(_, opts)
			require("copilot").setup(opts)

			local ok, cmp = pcall(require, "cmp")
			if ok then
				cmp.event:on("menu_opened", function()
					vim.b.copilot_suggestion_hidden = true
				end)

				cmp.event:on("menu_closed", function()
					vim.b.copilot_suggestion_hidden = false
				end)
			end
		end,
	},
}
