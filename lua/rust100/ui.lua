local M = {}

local dashboard_ns = vim.api.nvim_create_namespace("rust100.dashboard")
local output_ns = vim.api.nvim_create_namespace("rust100.check-output")
local output_window

local function close_window(window)
  if window and vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_win_close(window, true)
  end
end

local function progress_bar(completed, total, width)
  local filled = total > 0 and math.floor(width * completed / total) or 0
  return string.rep("━", filled) .. string.rep("─", width - filled)
end

local function truncate(value, width)
  if vim.fn.strdisplaywidth(value) <= width then
    return value
  end
  return vim.fn.strcharpart(value, 0, math.max(1, width - 1)) .. "…"
end

local function dashboard_lines(exercises, state, selected)
  local total = #exercises
  local completed = require("rust100.state").completed_count(state, exercises)
  local available_height = math.max(1, vim.o.lines - 4)
  local panel_width = math.max(1, math.min(88, vim.o.columns - 4))
  local compact = available_height < 20 or panel_width < 74
  local visible = math.min(total, compact and math.max(1, available_height - 11) or math.min(7, available_height - 14))
  local start_index = math.max(1, math.min(total - visible + 1, selected - math.floor((visible - 1) / 2)))
  local width = math.min(30, math.max(8, panel_width - 54))
  local chosen = exercises[selected]
  local lines = {
    "",
    compact and "  RUST 100 · NEOVIM" or "  RUST 100  /  LEARN IN NEOVIM",
    compact and ("  " .. completed .. " / " .. total .. " complete") or "  Read the lesson. Solve the exercise. Keep moving.",
    "",
    "  " .. progress_bar(completed, total, width),
    "",
    compact and "  SELECTED" or "  SELECTED EXERCISE",
    "  " .. truncate(chosen.title, math.max(12, panel_width - 4)),
    "  " .. chosen.chapter .. " / " .. chosen.name,
  }
  local selected_line = 8

  if not compact then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "  " .. completed .. " of " .. total .. " exercises complete"
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = compact and "  NEARBY" or "  COURSE MAP"
  local first_item_line = #lines
  local item_lines = {}

  for index = start_index, start_index + visible - 1 do
    local exercise = exercises[index]
    local marker = state.completed[exercise.id] == true and "✓" or "·"
    if index == selected then
      marker = "›"
    end
    local label = exercise.chapter .. " / " .. exercise.name
    local label_width = math.max(12, math.floor((panel_width - 10) * 0.58))
    label = truncate(label, label_width)
    local title_width = math.max(5, panel_width - vim.fn.strdisplaywidth(label) - 14)
    local text = string.format("  %s %s  %s", marker, label, truncate(exercise.title, title_width))
    lines[#lines + 1] = text
    item_lines[#item_lines + 1] = { line = #lines - 1, index = index }
  end

  lines[#lines + 1] = ""
  local footer = compact and "  j/k browse · Enter open · r check · q close" or "  j/k select   Enter open   l lesson   r verify   ? help   q close"
  lines[#lines + 1] = truncate(footer, panel_width - 2)

  return lines, selected_line, first_item_line, item_lines
end

function M.dashboard(exercises, state, handlers)
  local selected = math.max(1, math.min(#exercises, state.current or 1))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "rust100://dashboard")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "rust100"
  vim.bo[buf].modifiable = false

  local width = math.max(1, math.min(88, vim.o.columns - 4))
  local row_limit = math.max(1, vim.o.lines - 2)
  local height = math.min(row_limit, 24)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
      return
    end

    local lines, selected_line, first_item_line, item_lines = dashboard_lines(exercises, state, selected)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, dashboard_ns, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Title", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Comment", 2, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Special", 4, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Title", 6, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Comment", 7, 0, -1)
    if selected_line >= 0 then
      vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Identifier", selected_line, 0, -1)
    end
    for _, row in ipairs(item_lines) do
      local exercise = exercises[row.index]
      local group = row.index == selected and "Title" or (state.completed[exercise.id] and "DiagnosticOk" or "Normal")
      vim.api.nvim_buf_add_highlight(buf, dashboard_ns, group, row.line, 0, -1)
    end
    if vim.api.nvim_win_is_valid(win) then
      local selected_row
      for _, item in ipairs(item_lines) do
        if item.index == selected then
          selected_row = item.line
          break
        end
      end
      if selected_row then
        vim.api.nvim_win_set_cursor(win, { selected_row + 1, 0 })
      else
        vim.api.nvim_win_set_cursor(win, { math.min(first_item_line + 1, #lines), 0 })
      end
    end
  end

  local function close_and_call(callback)
    close_window(win)
    callback(selected)
  end

  local function move(delta)
    selected = math.max(1, math.min(#exercises, selected + delta))
    render()
  end

  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", function()
    close_window(win)
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    close_window(win)
  end, opts)
  vim.keymap.set("n", "j", function()
    move(1)
  end, opts)
  vim.keymap.set("n", "<Down>", function()
    move(1)
  end, opts)
  vim.keymap.set("n", "k", function()
    move(-1)
  end, opts)
  vim.keymap.set("n", "<Up>", function()
    move(-1)
  end, opts)
  vim.keymap.set("n", "<CR>", function()
    close_and_call(handlers.open)
  end, opts)
  vim.keymap.set("n", "l", function()
    close_and_call(handlers.lesson)
  end, opts)
  vim.keymap.set("n", "r", function()
    close_and_call(handlers.check)
  end, opts)
  vim.keymap.set("n", "?", function()
    vim.notify("Enter open · l read the lesson · r verify · j/k browse · q close", vim.log.levels.INFO, { title = "Rust 100" })
  end, opts)

  render()
end

function M.show_check_failure(output)
  close_window(output_window)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "rust100://check/" .. buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "text"

  output = (output or ""):gsub("\27%[[%d;]*[A-Za-z]", "")
  local lines = vim.split(output, "\n", { plain = true })
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  if #lines == 0 then
    lines = { "The workshop runner failed without returning output." }
  end
  table.insert(lines, 1, "RUST 100 · CHECK FAILED · press q to close")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local width = math.max(1, math.min(vim.o.columns - 4, 100))
  local height = math.max(1, math.min(#lines, 16, vim.o.lines - 2))
  output_window = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = math.max(0, vim.o.lines - height - 3),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })
  vim.wo[output_window].wrap = true
  vim.wo[output_window].winhl = "Normal:NormalFloat,FloatBorder:DiagnosticError"
  vim.api.nvim_buf_add_highlight(buf, output_ns, "DiagnosticError", 0, 0, -1)
  vim.keymap.set("n", "q", function()
    close_window(output_window)
    output_window = nil
  end, { buffer = buf, silent = true, nowait = true })
end

return M
