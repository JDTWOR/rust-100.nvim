local course = require("rust100.course")
local progress = require("rust100.state")
local ui = require("rust100.ui")
local bootstrap = require("rust100.bootstrap")

local M = {}
local config = { course_root = nil, auto_setup = true, auto_check = true, auto_check_delay = 700 }
local check_running = false
local open_exercise, open_lesson, check_exercise, open_dashboard, find_todos
local auto_check_group = vim.api.nvim_create_augroup("Rust100AutoCheck", { clear = true })
local auto_check_timers = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Rust 100" })
end

local function context(root)
  if not root then
    return nil, "No se encontró el curso."
  end

  local exercises, err = course.load(root)
  if not exercises then
    return nil, err
  end

  local state, state_path, is_new = progress.load(root, exercises)
  if is_new then
    local saved, save_error = progress.save(state, state_path)
    if not saved then
      notify("No se pudo inicializar el progreso: " .. tostring(save_error), vim.log.levels.WARN)
    end
  end
  return {
    root = root,
    exercises = exercises,
    state = state,
    state_path = state_path,
  }
end

local function save(ctx)
  ctx.state.current_id = ctx.exercises[ctx.state.current].id
  local ok, err = progress.save(ctx.state, ctx.state_path)
  if not ok then
    notify("No se pudo guardar el progreso: " .. tostring(err), vim.log.levels.WARN)
  end
end

local function current_index(ctx)
  local path = vim.api.nvim_buf_get_name(0)
  return course.index_for_path(ctx.exercises, path) or ctx.state.current
end

local function schedule_auto_check(ctx, exercise, index, buf)
  if not config.auto_check then
    return
  end

  local existing = auto_check_timers[buf]
  if existing then
    existing:stop()
    existing:close()
  end

  local timer = vim.uv.new_timer()
  auto_check_timers[buf] = timer
  timer:start(config.auto_check_delay, 0, vim.schedule_wrap(function()
    if auto_check_timers[buf] ~= timer then
      return
    end
    auto_check_timers[buf] = nil
    timer:close()
    if vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then
      exercise.markers = course.todo_markers(exercise)
      exercise.task = course.task_summary(exercise.markers)
      exercise.focus_line = course.focus_line(exercise, exercise.markers)
      ui.refresh_tasks(buf, exercise)
      check_exercise(ctx, index)
    end
  end))

  vim.api.nvim_clear_autocmds({ group = auto_check_group, buffer = buf })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = auto_check_group,
    buffer = buf,
    callback = function()
      schedule_auto_check(ctx, exercise, index, buf)
    end,
    desc = "Verify the current Rust 100 exercise after saving",
  })
end

local function open_buffers(ctx, index)
  local exercise = ctx.exercises[index]
  if course.normalize(vim.api.nvim_buf_get_name(0)) ~= course.normalize(exercise.source) then
    vim.cmd("edit " .. vim.fn.fnameescape(exercise.source))
  end
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].bufhidden = "hide"
  ui.study_buffer(buf, exercise, index, #ctx.exercises, ctx.state.completed[exercise.id] == true, {
    lesson = function()
      open_lesson(ctx, index)
    end,
    check = function()
      check_exercise(ctx, index)
    end,
    todos = function()
      find_todos(ctx, index)
    end,
    dashboard = function()
      open_dashboard(ctx)
    end,
    next = function()
      open_exercise(ctx, index + 1)
    end,
    previous = function()
      if index > 1 then
        open_exercise(ctx, index - 1)
      else
        notify("Este ya es el primer ejercicio.")
      end
    end,
  })
  schedule_auto_check(ctx, exercise, index, buf)
  local focus_line = course.focus_line(exercise, exercise.markers)
  vim.api.nvim_win_set_cursor(0, { focus_line, 0 })
  vim.cmd("normal! zz")
end

local function run_system(command, cwd, callback)
  local ok, process_or_error = pcall(vim.system, command, { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      callback(result)
    end)
  end)

  if not ok then
    vim.schedule(function()
      callback({ code = 127, stdout = "", stderr = tostring(process_or_error) })
    end)
  end
end

local function register_exercise(ctx, exercise, callback)
  if vim.fn.executable("wr") ~= 1 then
    callback({ code = 127, stdout = "", stderr = "El verificador `wr` no está instalado." })
    return
  end

  run_system({ "wr", "open", "--chapter", exercise.chapter, "--exercise", exercise.name }, ctx.root, callback)
end

open_exercise = function(ctx, index)
  if not ctx.exercises[index] then
    notify("No hay más ejercicios en el curso.")
    return
  end

  ctx.state.current = index
  save(ctx)
  local ok, err = pcall(open_buffers, ctx, index)
  if not ok then
    notify("No se pudo abrir el ejercicio: " .. tostring(err), vim.log.levels.ERROR)
  end
end

open_lesson = function(ctx, index)
  local exercise = ctx.exercises[index]
  if not exercise then
    notify("No existe un ejercicio en la posición " .. tostring(index) .. ".", vim.log.levels.ERROR)
    return
  end

  ctx.state.current = index
  save(ctx)
  local ok, err = pcall(open_buffers, ctx, index)
  if not ok then
    notify("No se pudo preparar el ejercicio: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  local code_buf = vim.api.nvim_get_current_buf()
  vim.cmd("edit " .. vim.fn.fnameescape(exercise.lesson))
  local lesson_buf = vim.api.nvim_get_current_buf()
  ui.lesson_buffer(lesson_buf, exercise, function()
    if vim.api.nvim_buf_is_valid(code_buf) then
      vim.api.nvim_set_current_buf(code_buf)
      ui.update_study(code_buf, exercise, index, #ctx.exercises, ctx.state.completed[exercise.id] == true)
    else
      open_exercise(ctx, index)
    end
  end)
end

local function show_check_error(result, ctx, exercise, index)
  local output = (result.stdout or "") .. (result.stderr or "")
  ui.show_check_failure(output)
  ctx.state.completed[exercise.id] = nil
  save(ctx)
  ui.update_study(vim.fn.bufnr(exercise.source), exercise, index, #ctx.exercises, false, "PENDIENTE")
  ui.refresh_dashboard(ctx.state)
  notify("Aún no pasa. Revisa la salida y vuelve a guardar.", vim.log.levels.WARN)
end

local function run_check(ctx, exercise, index)
  register_exercise(ctx, exercise, function(open_result)
    if open_result.code ~= 0 then
      check_running = false
      show_check_error(open_result, ctx, exercise, index)
      return
    end

    run_system({ "wr", "check" }, exercise.dir, function(result)
      check_running = false
      if result.code ~= 0 then
        show_check_error(result, ctx, exercise, index)
        return
      end

      ctx.state.completed[exercise.id] = true
      ctx.state.current = index
      save(ctx)
      ui.update_study(vim.fn.bufnr(exercise.source), exercise, index, #ctx.exercises, true)
      ui.refresh_dashboard(ctx.state)
      notify("Resuelto. Usa <leader>rn cuando quieras seguir.", vim.log.levels.INFO)
    end)
  end)
end

check_exercise = function(ctx, index)
  local exercise = ctx.exercises[index]
  if not exercise then
    notify("No existe un ejercicio en la posición " .. tostring(index) .. ".", vim.log.levels.ERROR)
    return
  end
  if check_running then
    notify("Ya hay una comprobación en curso.", vim.log.levels.WARN)
    return
  end

  check_running = true
  ctx.state.current = index
  save(ctx)
  ui.update_study(vim.fn.bufnr(exercise.source), exercise, index, #ctx.exercises, ctx.state.completed[exercise.id] == true, "PREPARANDO")
  notify("Preparando la comprobación de " .. exercise.chapter .. "/" .. exercise.name .. "…")
  bootstrap.ensure_runner(config, function(ready, err)
    if not ready then
      check_running = false
      ui.update_study(vim.fn.bufnr(exercise.source), exercise, index, #ctx.exercises, ctx.state.completed[exercise.id] == true, "PENDIENTE")
      notify(err, vim.log.levels.ERROR)
      return
    end
    ui.update_study(vim.fn.bufnr(exercise.source), exercise, index, #ctx.exercises, ctx.state.completed[exercise.id] == true, "VERIFICANDO")
    notify("Comprobando " .. exercise.chapter .. "/" .. exercise.name .. "…")
    run_check(ctx, exercise, index)
  end)
end

open_dashboard = function(ctx)
  ui.dashboard(ctx.exercises, ctx.state, {
    select = function(index)
      ctx.state.current = index
      save(ctx)
    end,
    open = function(index)
      open_exercise(ctx, index)
    end,
    lesson = function(index)
      open_lesson(ctx, index)
    end,
    check = function(index)
      check_exercise(ctx, index)
    end,
  })
end

find_todos = function(ctx, index)
  local exercise = ctx.exercises[index]
  if not exercise then
    notify("No existe un ejercicio en la posición " .. tostring(index) .. ".", vim.log.levels.ERROR)
    return
  end

  exercise.markers = course.todo_markers(exercise)
  exercise.task = course.task_summary(exercise.markers)
  exercise.focus_line = course.focus_line(exercise, exercise.markers)
  local items = {}
  for _, marker in ipairs(exercise.markers or {}) do
    items[#items + 1] = {
      filename = marker.filename,
      lnum = marker.lnum,
      col = marker.col,
      text = marker.text,
    }
  end

  vim.fn.setqflist({}, " ", {
    title = "Tareas pendientes · " .. exercise.chapter .. "/" .. exercise.name,
    items = items,
  })
  if #items == 0 then
    notify("Este ejercicio no tiene marcadores TODO.")
    return
  end
  vim.cmd("copen")
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.health()
  local lines = { "Estado de Rust 100" }
  for _, command in ipairs({ "git", "cargo", "rustc" }) do
    local status = vim.fn.executable(command) == 1 and "disponible" or "falta"
    lines[#lines + 1] = string.format("%s: %s", command, status)
  end
  local runner_status
  if bootstrap.runner_available() then
    runner_status = "disponible"
  elseif config.auto_setup and vim.fn.executable("cargo") == 1 and vim.fn.executable("rustc") == 1 then
    runner_status = "se instalará automáticamente"
  else
    runner_status = "falta"
  end
  lines[#lines + 1] = string.format("wr: %s", runner_status)
  lines[#lines + 1] = string.format("rust-analyzer: %s (opcional)", vim.fn.executable("rust-analyzer") == 1 and "disponible" or "falta")

  local root, target = bootstrap.course_target(config)
  if root then
    lines[#lines + 1] = "curso: " .. root
  elseif config.auto_setup then
    lines[#lines + 1] = "curso: se descargará en " .. target
  else
    lines[#lines + 1] = "curso: no encontrado"
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Rust 100" })
end

local function dispatch(ctx, args)
  local action = args[1] or "dashboard"
  local index = tonumber(args[2]) or current_index(ctx)
  if action == "dashboard" or action == "list" then
    open_dashboard(ctx)
  elseif action == "open" then
    open_exercise(ctx, index)
  elseif action == "lesson" then
    open_lesson(ctx, index)
  elseif action == "check" then
    check_exercise(ctx, index)
  elseif action == "next" then
    open_exercise(ctx, index + 1)
  elseif action == "todos" then
    find_todos(ctx, index)
  else
    notify("Acción desconocida. Ejecuta :Rust100 para abrir el curso.", vim.log.levels.ERROR)
  end
end

function M.command(args)
  args = args or {}
  local action = args[1] or "dashboard"
  if action == "health" then
    M.health()
    return
  end

  local supported = { dashboard = true, list = true, open = true, lesson = true, check = true, next = true, todos = true }
  if not supported[action] then
    notify("Acción desconocida. Ejecuta :Rust100 para abrir el curso.", vim.log.levels.ERROR)
    return
  end

  bootstrap.ensure_course(config, function(root, setup_error)
    if not root then
      notify(setup_error, vim.log.levels.ERROR)
      return
    end

    local ctx, context_error = context(root)
    if not ctx then
      notify(context_error, vim.log.levels.ERROR)
      return
    end

    if action ~= "check" then
      bootstrap.ensure_runner(config, function(ready, runner_error)
        if not ready then
          notify(runner_error, vim.log.levels.WARN)
        end
      end)
    end

    dispatch(ctx, args)
  end)
end

function M.complete(arglead)
  local actions = { "dashboard", "open", "lesson", "check", "next", "todos", "health" }
  return vim.tbl_filter(function(action)
    return action:find(arglead, 1, true) == 1
  end, actions)
end

return M
