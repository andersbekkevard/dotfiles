local oil_open_rules = {
	browser_extensions = {
		html = true,
		htm = true,
		pdf = true,
		png = true,
		jpg = true,
		jpeg = true,
	},
	default_app_extensions = {
		doc = true,
		docx = true,
		ppt = true,
		pptx = true,
		xls = true,
		xlsm = true,
		xlsx = true,
	},
}

-- Extension routing might not scale; replace this with MIME/app rules if it grows.
local function entry_extension(entry)
	if not entry or entry.type ~= "file" then
		return nil
	end

	return (entry.name:match("^.+%.([^.]+)$") or ""):lower()
end

local function should_open_in_browser(entry)
	local ext = entry_extension(entry)
	return oil_open_rules.browser_extensions[ext] == true
end

local function should_open_in_default_app(entry)
	local ext = entry_extension(entry)
	return oil_open_rules.default_app_extensions[ext] == true
end

local function oil_entry_path(entry)
	local dir = require("oil").get_current_dir()
	if not dir or not entry then
		return nil
	end
	return dir .. entry.name
end

local function has_desktop_session()
	return (vim.env.DISPLAY ~= nil and vim.env.DISPLAY ~= "")
		or (vim.env.WAYLAND_DISPLAY ~= nil and vim.env.WAYLAND_DISPLAY ~= "")
end

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
		if not has_desktop_session() then
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

local function open_in_default_app(path)
	local sysname = (vim.loop.os_uname() or {}).sysname or ""

	if sysname == "Darwin" then
		vim.fn.jobstart({ "open", path }, { detach = true })
		return true
	end

	if sysname == "Linux" then
		if not has_desktop_session() then
			return false
		end

		for _, opener in ipairs({ "xdg-open", "gio" }) do
			if vim.fn.executable(opener) == 1 then
				local command = opener == "gio" and { "gio", "open", path } or { opener, path }
				vim.fn.jobstart(command, { detach = true })
				return true
			end
		end
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
			-- Keep open Oil buffers synchronized with external filesystem changes.
			watch_for_changes = true,
			view_options = {
				-- Show files and directories that start with "."
				show_hidden = true,
			},
			-- Keymaps in oil buffer
			keymaps = {
				["g?"] = "actions.show_help",
				["<CR>"] = {
					desc = "Open configured external file types, else default select",
					callback = function()
						local oil = require("oil")
						local entry = oil.get_cursor_entry()
						if should_open_in_browser(entry) then
							local full_path = oil_entry_path(entry)
							if full_path and open_in_browser(full_path) then
								return
							end
						end
						if should_open_in_default_app(entry) then
							local full_path = oil_entry_path(entry)
							if full_path and open_in_default_app(full_path) then
								return
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
