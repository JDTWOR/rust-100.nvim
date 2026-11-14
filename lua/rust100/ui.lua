local M = {}

local dashboard_ns = vim.api.nvim_create_namespace("rust100.dashboard")
local output_ns = vim.api.nvim_create_namespace("rust100.check-output")
local exercise_ns = vim.api.nvim_create_namespace("rust100.exercise-tasks")
local output_window
local dashboard_views = {}

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

local function dashboard_lines(exercises, state, selected, panel_width, panel_height)
  local total = #exercises
  local completed = require("rust100.state").completed_count(state, exercises)
  local compact = panel_height < 20 or panel_width < 78
  local reserved = compact and 15 or 16
  local visible = math.max(1, math.min(total, 7, panel_height - reserved))
  local start_index = math.max(1, math.min(total - visible + 1, selected - math.floor((visible - 1) / 2)))
  local chosen = exercises[selected]
  local header = compact and "  RUST 100 · TALLER DE RUST" or "  RUST 100                                                   TALLER DE RUST"
  local lines = {
    "",
    truncate(header, panel_width - 4),
    truncate("  Aprende un concepto, resuelve una tarea y comprueba tu código.", panel_width - 4),
    "",
    string.format("  AVANCE   %d / %d resueltos", completed, total),
    "  " .. progress_bar(completed, total, math.min(34, math.max(8, panel_width - 12))),
    "",
    "  EJERCICIO ACTUAL",
    "  " .. truncate(chosen.title, math.max(12, panel_width - 4)),
    "  " .. chosen.chapter .. " / " .. chosen.name,
    "  Tarea: " .. truncate(chosen.task or "Lee la lección y completa el ejercicio.", math.max(12, panel_width - 12)),
    "",
    "  MAPA DEL CURSO",
  }
  local selected_line = 8
  local map_line = #lines - 1
  local first_item_line = #lines
  local item_lines = {}

  for index = start_index, start_index + visible - 1 do
    local exercise = exercises[index]
    local marker = state.completed[exercise.id] == true and "✓" or " "
    if index == selected then
      marker = "›"
    end
    local label = exercise.chapter .. " / " .. exercise.name
    local label_width = math.max(12, math.floor((panel_width - 12) * 0.52))
    label = truncate(label, label_width)
    local title_width = math.max(5, panel_width - vim.fn.strdisplaywidth(label) - 14)
    local text = string.format("  %s  %s  %s", marker, label, truncate(exercise.title, title_width))
    lines[#lines + 1] = text
    item_lines[#item_lines + 1] = { line = #lines - 1, index = index }
  end

  lines[#lines + 1] = ""
  local footer = compact and "  j/k mover · Enter abrir · l leer · q cerrar" or "  j/k mover   Enter abrir   l leer teoría   r comprobar   ? ayuda   q cerrar"
  lines[#lines + 1] = truncate(footer, panel_width - 2)

  return lines, selected_line, map_line, first_item_line, item_lines
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

  local width = math.max(1, math.min(100, vim.o.columns - 4))
  local row_limit = math.max(1, vim.o.lines - 2)
  local height = math.min(row_limit, 26)
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
  vim.wo[win].winbar = ""
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
      return
    end

    local lines, selected_line, map_line, first_item_line, item_lines = dashboard_lines(exercises, state, selected, width, height)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, dashboard_ns, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Title", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Comment", 2, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Special", 4, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Title", 7, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Comment", 8, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Comment", 9, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "WarningMsg", 10, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, dashboard_ns, "Title", map_line, 0, -1)
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

  dashboard_views[buf] = { render = render, state = state }
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      dashboard_views[buf] = nil
    end,
  })

  local function close_and_call(callback)
    close_window(win)
    callback(selected)
  end

  local function move(delta)
    selected = math.max(1, math.min(#exercises, selected + delta))
    if handlers.select then
      handlers.select(selected)
    end
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
    vim.notify("Enter abre el ejercicio · l lee la lección · r comprueba · j/k recorren · q cierra", vim.log.levels.INFO, { title = "Rust 100" })
  end, opts)

  render()
end

function M.refresh_dashboard(state)
  for buf, view in pairs(dashboard_views) do
    if view.state == state then
      if vim.api.nvim_buf_is_valid(buf) then
        view.render()
      else
        dashboard_views[buf] = nil
      end
    end
  end
end

local function leader_label()
  local leader = vim.g.mapleader or "\\"
  if leader == " " then
    return "<Space>"
  end
  return leader
end

local function study_winbar(exercise, index, total, completed, status)
  status = status or (completed and "RESUELTO" or "PENDIENTE")
  local leader = leader_label()
  return string.format(
    "  RUST 100  ·  %s / %s  ·  %d/%d  ·  %s  ·  [%srl] lección  [%srr] comprobar  [%srt] tareas  [%srn] siguiente",
    exercise.chapter,
    exercise.name,
    index,
    total,
    status,
    leader,
    leader,
    leader,
    leader
  )
end

local function mark_tasks(buf, exercise)
  vim.api.nvim_buf_clear_namespace(buf, exercise_ns, 0, -1)
  for _, marker in ipairs(exercise.markers or {}) do
    if marker.filename == exercise.source then
      vim.api.nvim_buf_set_extmark(buf, exercise_ns, marker.lnum - 1, 0, {
        sign_text = "›",
        sign_hl_group = "DiagnosticWarn",
        line_hl_group = "CursorLine",
        priority = 110,
      })
    end
  end
  local win = vim.fn.win_findbuf(buf)[1]
  local width = win and vim.api.nvim_win_get_width(win) or vim.o.columns
  local task = "  TAREA  " .. (exercise.task or "Lee la lección y completa el ejercicio.")
  if vim.fn.strdisplaywidth(task) > width - 6 then
    task = vim.fn.strcharpart(task, 0, math.max(12, width - 7)) .. "…"
  end
  vim.api.nvim_buf_set_extmark(buf, exercise_ns, math.max(0, (exercise.focus_line or 1) - 1), 0, {
    virt_lines = { { { task, "Title" } } },
    virt_lines_above = true,
    virt_lines_leftcol = true,
    priority = 120,
  })
end

function M.study_buffer(buf, exercise, index, total, completed, handlers)
  local windows = vim.fn.win_findbuf(buf)
  for _, win in ipairs(windows) do
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    vim.wo[win].breakindent = true
    vim.wo[win].number = true
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "yes:1"
    vim.wo[win].winbar = study_winbar(exercise, index, total, completed)
  end

  mark_tasks(buf, exercise)

  local opts = { buffer = buf, silent = true, desc = "Rust 100" }
  vim.keymap.set("n", "<leader>rl", handlers.lesson, vim.tbl_extend("force", opts, { desc = "Leer la lección" }))
  vim.keymap.set("n", "<leader>rr", handlers.check, vim.tbl_extend("force", opts, { desc = "Comprobar ejercicio" }))
  vim.keymap.set("n", "<leader>rt", handlers.todos, vim.tbl_extend("force", opts, { desc = "Buscar tareas pendientes" }))
  vim.keymap.set("n", "<leader>rm", handlers.dashboard, vim.tbl_extend("force", opts, { desc = "Mapa del curso" }))
  vim.keymap.set("n", "<leader>rn", handlers.next, vim.tbl_extend("force", opts, { desc = "Siguiente ejercicio" }))
  vim.keymap.set("n", "<leader>rp", handlers.previous, vim.tbl_extend("force", opts, { desc = "Ejercicio anterior" }))
end

function M.refresh_tasks(buf, exercise)
  if vim.api.nvim_buf_is_valid(buf) then
    mark_tasks(buf, exercise)
  end
end

function M.update_study(buf, exercise, index, total, completed, status)
  if not buf or buf < 1 or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win].winbar = study_winbar(exercise, index, total, completed, status)
  end
end

function M.lesson_buffer(buf, exercise, on_return)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].conceallevel = 2
  vim.bo[buf].concealcursor = "nc"
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    vim.wo[win].breakindent = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].winbar = string.format("  RUST 100  ·  LECCIÓN  ·  %s / %s  ·  q volver al código", exercise.chapter, exercise.name)
  end
  vim.keymap.set("n", "q", on_return, { buffer = buf, silent = true, desc = "Volver al ejercicio" })
  vim.keymap.set("n", "<leader>rm", on_return, { buffer = buf, silent = true, desc = "Volver al ejercicio" })
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
    lines = { "El verificador terminó sin devolver detalles." }
  end
  table.insert(lines, 1, "RUST 100 · NO PASÓ · salida completa de wr · q cerrar")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local width = math.max(1, math.min(vim.o.columns - 4, 112))
  local height = math.max(1, math.min(#lines, 18, vim.o.lines - 2))
  output_window = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(0, vim.o.lines - height - 3),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })
  vim.wo[output_window].wrap = true
  vim.wo[output_window].linebreak = true
  vim.wo[output_window].number = false
  vim.wo[output_window].signcolumn = "no"
  vim.wo[output_window].winbar = "  RUST 100  ·  RESULTADO  ·  q volver"
  vim.wo[output_window].winhl = "Normal:NormalFloat,FloatBorder:DiagnosticError"
  vim.api.nvim_buf_add_highlight(buf, output_ns, "DiagnosticError", 0, 0, -1)
  vim.keymap.set("n", "q", function()
    close_window(output_window)
    output_window = nil
  end, { buffer = buf, silent = true, nowait = true })
end

return M
