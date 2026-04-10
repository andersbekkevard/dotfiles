-- Try to open `path` in Comet, fall back to Chrome. Returns true if a job
-- was launched. Safe on headless Linux: returns false instead of crashing.
local function open_in_browser(path)
	local sysname = (vim.loop.os_uname() or {}).sysname or ""

	if sysname == "Darwin" then
		local has_comet = vim.fn.isdirectory("/Applications/Comet.app") == 1
		local has_chrome = vim.fn.isdirectory("/Applications/Google Chrome.app") == 1
		local browser = has_comet and "Comet" or (has_chrome and "Google Chrome" or nil)
		if not browser then
			return false
		end
		vim.fn.jobstart({ "open", "-a", browser, path }, {
			detach = true,
			on_exit = function(_, code)
				if code ~= 0 and browser == "Comet" and has_chrome then
					vim.schedule(function()
						vim.fn.jobstart({ "open", "-a", "Google Chrome", path }, { detach = true })
					end)
				end
			end,
		})
		return true
	end

	if sysname == "Linux" then
		-- Headless: no display server -> bail out cleanly
		if (vim.env.DISPLAY == nil or vim.env.DISPLAY == "")
			and (vim.env.WAYLAND_DISPLAY == nil or vim.env.WAYLAND_DISPLAY == "") then
			return false
		end
		-- Same hierarchy: Comet first, then Chrome variants
		local candidates = { "comet", "google-chrome", "google-chrome-stable", "chromium", "chromium-browser" }
		for _, bin in ipairs(candidates) do
			if vim.fn.executable(bin) == 1 then
				vim.fn.jobstart({ bin, path }, { detach = true })
				return true
			end
		end
		return false
	end

	return false
end

return {
	-------------------------------------------------------------------------------
	--
	-- Oil.nvim - File explorer that lets you edit your filesystem like a buffer
	--
	-------------------------------------------------------------------------------
	{
		"stevearc/oil.nvim",
		dependencies = { "echasnovski/mini.icons" },
		lazy = false,
		opts = {
			view_options = {
				-- Show files and directories that start with "."
				show_hidden = true,
			},
			-- Keymaps in oil buffer
			keymaps = {
				["g?"] = "actions.show_help",
				["<CR>"] = {
					desc = "Open PNG/PDF in Comet (fallback Chrome), else default select",
					callback = function()
						local oil = require("oil")
						local entry = oil.get_cursor_entry()
						if entry and entry.type == "file" then
							local ext = (entry.name:match("^.+%.([^.]+)$") or ""):lower()
							if ext == "png" or ext == "pdf" or ext == "jpg" or ext == "jpeg" then
								local full_path = (oil.get_current_dir() or "") .. entry.name
								if open_in_browser(full_path) then
									return
								end
							end
						end
						oil.select()
					end,
				},
				["<C-s>"] = "actions.select_vsplit",
				["<C-h>"] = "actions.select_split",
				["<C-t>"] = false, -- Disabled to use Ctrl-t for Telescope globally
				["<C-p>"] = "actions.preview",
				["<C-c>"] = "actions.close",
				["<C-l>"] = "actions.refresh",
				["-"] = "actions.parent",
				["_"] = "actions.open_cwd",
				["`"] = false,
				["~"] = false,
				["."] = "actions.cd",
				["gs"] = "actions.change_sort",
				["gx"] = "actions.open_external",
				["g."] = "actions.toggle_hidden",
				["g\\"] = "actions.toggle_trash",
			},
		},
		config = function(_, opts)
			require("oil").setup(opts)
			
			-- Global keybinding to open Oil
			vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
		end,
	},
}