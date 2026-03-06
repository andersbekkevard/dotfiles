return {
	-------------------------------------------------------------------------------
	--
	-- 99 - LLM prompting helper inside Neovim
	--
	-------------------------------------------------------------------------------
	{
		"ThePrimeagen/99",
		keys = {
			{
				"9v",
				function()
					require("99").visual()
				end,
				mode = "v",
				desc = "Open 99 prompt for visual selection",
			},
			{
				"9s",
				function()
					require("99").stop_all_requests()
				end,
				mode = { "n", "v" },
				desc = "Stop all 99 requests",
			},
		},
		dependencies = {
			"hrsh7th/nvim-cmp",
		},
		config = function()
			local _99 = require("99")
			local BaseProvider = _99.Providers.BaseProvider

			-- Uncomment to use Claude Code (built-in provider).
			-- local provider = _99.Providers.ClaudeCodeProvider
			-- local model = "claude-sonnet-4-5"

			-- Active provider: Codex CLI wrapper that writes the final assistant
			-- message directly to TEMP_FILE so 99 can apply it to your selection.
			local CodexProvider = setmetatable({}, { __index = BaseProvider })
			function CodexProvider._build_command(_, query, request)
				-- 99's default prompt expects the model to write TEMP_FILE itself.
				-- For Codex CLI, convert that into "print code only" and use
				-- `--output-last-message` to write to the TEMP_FILE path.
				local rewritten = query
					:gsub(
						"ONLY provide requested changes by writing the change to TEMP_FILE",
						"ONLY provide requested changes by printing the replacement code directly."
					)
					:gsub(
						"never attempt to read TEMP_FILE%.",
						"Do not read or mention TEMP_FILE."
					)
					:gsub(
						"After writing TEMP_FILE once you should be done%.  Be done and end the session%.",
						"After printing the replacement code, stop."
					)

				return {
					"codex",
					"exec",
					"--skip-git-repo-check",
					"-m",
					request.context.model,
					"--output-last-message",
					request.context.tmp_file,
					rewritten,
				}
			end
			function CodexProvider._get_provider_name()
				return "CodexProvider"
			end
			function CodexProvider._get_default_model()
				return "gpt-5-codex"
			end
			local provider = CodexProvider
			local model = "gpt-5-codex"

			-- 99 does not ship built-in providers for Codex/Copilot.
			-- If you want to try them, uncomment and adapt one of these providers:

			-- local CodexProvider = setmetatable({}, { __index = _99.Providers.BaseProvider })
			-- function CodexProvider._build_command(_, query, request)
			-- 	return { "codex", "exec", "-m", request.context.model, query }
			-- end
			-- function CodexProvider._get_provider_name()
			-- 	return "CodexProvider"
			-- end
			-- function CodexProvider._get_default_model()
			-- 	return "gpt-5-codex"
			-- end
			-- local provider = CodexProvider
			-- local model = "gpt-5-codex"

			-- local CopilotProvider = setmetatable({}, { __index = _99.Providers.BaseProvider })
			-- function CopilotProvider._build_command(_, query, request)
			-- 	-- Adjust args to match your installed Copilot CLI's non-interactive mode.
			-- 	return { "copilot", "chat", "--model", request.context.model, query }
			-- end
			-- function CopilotProvider._get_provider_name()
			-- 	return "CopilotProvider"
			-- end
			-- function CopilotProvider._get_default_model()
			-- 	return "gpt-4.1"
			-- end
			-- local provider = CopilotProvider
			-- local model = "gpt-4.1"

			_99.setup({
				provider = provider,
				model = model,
				logger = {
					level = _99.DEBUG,
					path = "/tmp/99.debug.log",
					print_on_error = true,
				},
				completion = {
					source = "cmp",
				},
			})
		end,
	},
}
