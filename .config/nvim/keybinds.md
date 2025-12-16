# Neovim Keybinds Summary

**Last Updated:** October 29, 2025

---

## Core Navigation

| Keybind | Mode | Action |
|---------|------|--------|
| `H` | All | Jump to start of line (instead of `^`) |
| `L` | All | Jump to end of line (instead of `$`) |
| `j` | Normal | Move down by visual line (soft-wrapped text) |
| `k` | Normal | Move up by visual line (soft-wrapped text) |
| `n` | Normal | Next search result (centered) |
| `N` | Normal | Previous search result (centered) |
| `<C-u>` | Normal | Scroll up half page (centered) |
| `<C-d>` | Normal | Scroll down half page (centered) |

---

## File & Buffer Management

| Keybind | Mode | Action |
|---------|------|--------|
| `<leader>w` | Normal | Quick save `:w` |
| `<leader>f` | Normal | Find existing buffers (Telescope) |
| `<leader>?` | Normal | Find recently opened files (Telescope) |
| `<leader><leader>` | Normal | Toggle between current and previous buffer |
| `+` | Normal | Navigate to previous buffer |
| `´` | Normal | Navigate to next buffer |

---

## File Navigation (Telescope)

| Keybind | Mode | Action |
|---------|------|--------|
| `<leader>sf` | Normal | Find files |
| `<leader>sws` | Normal | Search for word under cursor |
| `<leader>sWs` | Normal | Search for WORD under cursor (with special chars) |
| `<leader>sg` | Normal | Grep search (interactive input) |
| `<leader>vh` | Normal | View help tags |

---

## Clipboard & Deletion

| Keybind | Mode | Action |
|---------|------|--------|
| `<leader>y` | Normal, Visual | Yank to system clipboard |
| `<leader>Y` | Normal | Yank line to system clipboard |
| `<leader>d` | Normal, Visual | Delete to system clipboard |
| `<leader>D` | Normal | Delete line to system clipboard |
| `<leader>p` | Normal, Visual | Paste from system clipboard (after cursor/replace) |
| `<leader>P` | Normal, Visual | Paste from system clipboard (before cursor/replace) |
| `p` | Visual | Paste without overwriting unnamed register (greatest remap) |

---

## Text Editing & Find/Replace

| Keybind | Mode | Action |
|---------|------|--------|
| `<leader>m` | Normal | Change text up to next `_` (variable names) |
| `<leader>M` | Normal | Change text up to previous `_` (variable names) |
| `<leader>r` | Normal | Replace word under cursor with substitution pattern |
| `<Esc>` | Normal | Clear search highlight without saving |
| `<Esc>` | Insert | Standard escape (normal escape functionality) |

---

## Insert Mode - Undo Blocks

| Keybind | Mode | Action |
|---------|------|--------|
| `<Space>` | Insert | Insert space with undo block boundary |
| `.` | Insert | Insert period with undo block boundary |
| `,` | Insert | Insert comma with undo block boundary |
| `;` | Insert | Insert semicolon with undo block boundary |
| `:` | Insert | Insert colon with undo block boundary |
| `!` | Insert | Insert exclamation with undo block boundary |
| `?` | Insert | Insert question mark with undo block boundary |

---

## Completion Keybinds

| Keybind | Mode | Action |
|---------|------|--------|
| `<C-Space>` | Insert | Trigger completion menu |
| `<C-b>` | Insert | Scroll completion docs up |
| `<C-f>` | Insert | Scroll completion docs down |
| `<C-e>` | Insert | Abort completion |
| `<Tab>` | Insert | Select next completion item (or insert tab) |
| `<S-Tab>` | Insert | Select previous completion item |
| `<CR>` | Insert | Confirm completion selection |

---

## LSP & Diagnostics

| Keybind | Mode | Action |
|---------|------|--------|
| `<leader>e` | Normal | Open diagnostic float |
| `<leader>q` | Normal | Open diagnostic location list |

---

## File Explorer (Oil.nvim)

| Keybind | Mode | Action |
|---------|------|--------|
| `-` | Normal | Open Oil file explorer (parent directory) |

### Oil Buffer Navigation

| Keybind | Action |
|---------|--------|
| `g?` | Show help |
| `<CR>` | Select and open file/directory |
| `<C-s>` | Open in vertical split |
| `<C-h>` | Open in horizontal split |
| `<C-t>` | Open in new tab |
| `<C-p>` | Preview file |
| `<C-c>` | Close Oil |
| `<C-l>` | Refresh view |
| `-` | Go to parent directory |
| `_` | Open current working directory |
| `` ` `` | Change directory |
| `~` | Change to directory (tab-local) |
| `gs` | Change sort order |
| `gx` | Open file with external app |
| `g.` | Toggle hidden files |
| `g\` | Toggle trash |

---

## Flash.nvim (Code Navigation)

| Keybind | Mode | Action |
|---------|------|--------|
| `s` | Normal, Visual, Operator | Flash - Navigate with search labels |
| `<C-s>` | Command | Toggle Flash search |

---

## Git

| Keybind | Mode | Action |
|---------|------|--------|
| `<leader>lg` | Normal | Open LazyGit |

---

## Telescope Search Customizations

| Keybind | Mode | Action |
|---------|------|--------|
| `<C-c>` | Insert (in Telescope) | Close Telescope |

---

## Notes

- **Leader Key**: `<leader>` is typically mapped to space in Neovim configs
- **VSCode Integration**: Some keybinds (like LazyGit and buffer navigation) are only available in native Neovim, not when running Neovim in VSCode
- **Undo Blocks**: Punctuation in insert mode creates undo boundaries, allowing for more granular undo operations
