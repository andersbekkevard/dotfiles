return {
	{
		"akinsho/bufferline.nvim",
		dependencies = { "echasnovski/mini.icons" },
		lazy = false,
		config = function()
			local function delete_buffer(bufnr)
				local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
				if not ok then
					local name = vim.fn.bufname(bufnr)
					vim.notify(
						"Could not close buffer: " .. (name ~= "" and name or tostring(bufnr)) .. "\n" .. err,
						vim.log.levels.WARN
					)
				end
			end

			local active_tab_accent = "#0078D4"
			local active_tab_bg = "#1f1f1f"
			local active_tab_text = { fg = "#ffffff" }
			local active_tab_line = { sp = active_tab_accent, overline = true }
			local function active_tab_highlight(opts)
				return vim.tbl_extend("force", active_tab_line, active_tab_text, opts)
			end
			local overline_excluded_groups = {
				BufferLineSeparatorSelected = true,
			}
			local function set_selected_group_overlines()
				for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
					if name:match("^BufferLine.*Selected$") and not hl.link and not overline_excluded_groups[name] then
						hl.sp = active_tab_accent
						hl.overline = true
						vim.api.nvim_set_hl(0, name, hl)
					end
				end
			end
			local function apply_active_tab_overline()
				set_selected_group_overlines()
				vim.cmd.redrawtabline()
				set_selected_group_overlines()
				vim.cmd.redrawtabline()
			end

			require("bufferline").setup({
				options = {
					mode = "buffers",
					themable = false,
					numbers = "ordinal",
					diagnostics = "nvim_lsp",
					close_command = delete_buffer,
					right_mouse_command = delete_buffer,
					color_icons = true,
					separator_style = { "│", "│" },
					tab_size = 24,
					max_name_length = 22,
					enforce_regular_tabs = true,
					buffer_close_icon = "×",
					indicator = {
						style = "none",
					},
					show_buffer_close_icons = true,
					show_close_icon = false,
					hover = {
						enabled = true,
						delay = 100,
						reveal = { "close" },
					},
				},
				highlights = {
					fill = { bg = "#181818" },
					background = { fg = "#9d9d9d", bg = "#181818" },
					buffer_visible = { fg = "#cccccc", bg = "#1e1e1e" },
					buffer_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					numbers = { fg = "#858585", bg = "#181818" },
					numbers_visible = { fg = "#cccccc", bg = "#1e1e1e" },
					numbers_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					indicator_selected = active_tab_highlight({ bg = active_tab_bg }),
					separator = { fg = "#2b2b2b", bg = "#181818" },
					separator_visible = { fg = "#2b2b2b", bg = "#1e1e1e" },
					separator_selected = { fg = "#2b2b2b", bg = active_tab_bg },
					close_button = { fg = "#858585", bg = "#181818" },
					close_button_visible = { fg = "#cccccc", bg = "#1e1e1e" },
					close_button_selected = active_tab_highlight({ bg = active_tab_bg }),
					modified = { fg = "#d7ba7d", bg = "#181818" },
					modified_visible = { fg = "#d7ba7d", bg = "#1e1e1e" },
					modified_selected = active_tab_highlight({ bg = active_tab_bg }),
					diagnostic_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					error = { fg = "#f44747", bg = "#181818" },
					error_visible = { fg = "#f44747", bg = "#1e1e1e" },
					error_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					error_diagnostic_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					warning = { fg = "#cca700", bg = "#181818" },
					warning_visible = { fg = "#cca700", bg = "#1e1e1e" },
					warning_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					warning_diagnostic_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					hint = { fg = "#75beff", bg = "#181818" },
					hint_visible = { fg = "#75beff", bg = "#1e1e1e" },
					hint_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					hint_diagnostic_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					info_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					info_diagnostic_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
					duplicate_selected = active_tab_highlight({ bg = active_tab_bg, italic = false }),
					pick_selected = active_tab_highlight({ bg = active_tab_bg, bold = true, italic = false }),
				},
			})
			apply_active_tab_overline()
			vim.api.nvim_create_autocmd({ "BufEnter", "ColorScheme", "VimEnter", "WinEnter" }, {
				group = vim.api.nvim_create_augroup("AndersBufferlineCursorTabs", { clear = true }),
				callback = function()
					vim.schedule(apply_active_tab_overline)
				end,
			})
			vim.keymap.set("n", "<leader>xo", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
			for i = 1, 9 do
				-- Ctrl+number is unreliable in terminal/tmux, so provide tmux-safe fallbacks.
				vim.keymap.set("n", "<leader>" .. i, function()
					require("bufferline").go_to(i, true)
				end, { desc = "Go to buffer " .. i })
				vim.keymap.set("n", "<A-" .. i .. ">", function()
					require("bufferline").go_to(i, true)
				end, { desc = "Go to buffer " .. i })
				vim.keymap.set("n", "<C-" .. i .. ">", function()
					require("bufferline").go_to(i, true)
				end, { desc = "Go to buffer " .. i })
			end
		end,
	},
}
