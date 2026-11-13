local course = require("rust100.course")
local progress = require("rust100.state")
local ui = require("rust100.ui")
local bootstrap = require("rust100.bootstrap")

local M = {}
local config = { course_root = nil, auto_setup = true }
local check_running = false

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Rust 100" })
end

local function context(root)
  if not root then
    return nil, "Course not found."
  end

  local exercises, err = course.load(root)
  if not exercises then
    return nil, err
  end

  local state, state_path, is_new = progress.load(root, exercises)
  if is_new then
    local saved, save_error = progress.save(state, state_path)
    if not saved then
      notify("Could not initialize course progress: " .. tostring(save_error), vim.log.levels.WARN)
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
    notify("Could not save course progress: " .. tostring(err), vim.log.levels.WARN)
  end
end

local function current_index(ctx)
  local path = vim.api.nvim_buf_get_name(0)
  return course.index_for_path(ctx.exercises, path) or ctx.state.current
end

local function open_buffers(ctx, index)
  local exercise = ctx.exercises[index]
  vim.cmd("edit " .. vim.fn.fnameescape(exercise.source))
  local code_window = vim.api.nvim_get_current_win()

  if exercise.lesson ~= exercise.source then
    local split = vim.o.columns < 100 and "split" or "vsplit"
    vim.cmd("rightbelow " .. split .. " " .. vim.fn.fnameescape(exercise.lesson))
    if vim.api.nvim_win_is_valid(code_window) then
      vim.api.nvim_set_current_win(code_window)
    end
  end
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
    callback({ code = 127, stdout = "", stderr = "The `wr` workshop runner is not installed." })
    return
  end

  run_system({ "wr", "open", "--chapter", exercise.chapter, "--exercise", exercise.name }, ctx.root, callback)
end

local function open_exercise(ctx, index)
  if not ctx.exercises[index] then
    notify("There are no more exercises in the course.")
    return
  end

  ctx.state.current = index
  save(ctx)
  local ok, err = pcall(open_buffers, ctx, index)
  if not ok then
    notify("Could not open the exercise: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function open_lesson(ctx, index)
  local exercise = ctx.exercises[index]
  if not exercise then
    notify("There is no exercise at position " .. tostring(index) .. ".", vim.log.levels.ERROR)
    return
  end

  ctx.state.current = index
  save(ctx)
  vim.cmd("edit " .. vim.fn.fnameescape(exercise.lesson))
end

local function show_check_error(result)
  local output = (result.stdout or "") .. (result.stderr or "")
  ui.show_check_failure(output)
  notify("Check failed with exit code " .. tostring(result.code) .. ". Review the runner output.", vim.log.levels.WARN)
end

local function run_check(ctx, exercise, index)
  local active_path = course.normalize(vim.api.nvim_buf_get_name(0))
  local source_root = course.normalize(vim.fs.joinpath(exercise.dir, "src")) .. package.config:sub(1, 1)
  local is_rust_source = active_path:sub(1, #source_root) == source_root and active_path:match("%.rs$") ~= nil
  if not is_rust_source then
    local ok, err = pcall(open_buffers, ctx, index)
    if not ok then
      check_running = false
      notify("Could not open the exercise before checking: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
  end

  register_exercise(ctx, exercise, function(open_result)
    if open_result.code ~= 0 then
      check_running = false
      show_check_error(open_result)
      return
    end

    run_system({ "wr", "check" }, exercise.dir, function(result)
      check_running = false
      if result.code ~= 0 then
        show_check_error(result)
        return
      end

      ctx.state.completed[exercise.id] = true
      local next_index = index + 1
      if ctx.exercises[next_index] then
        ctx.state.current = next_index
        save(ctx)
        notify("Exercise solved. Opening the next lesson.", vim.log.levels.INFO)
        open_exercise(ctx, next_index)
      else
        ctx.state.current = index
        save(ctx)
        notify("All course exercises are complete. Nice work!", vim.log.levels.INFO)
      end
    end)
  end)
end

local function check_exercise(ctx, index)
  local exercise = ctx.exercises[index]
  if not exercise then
    notify("There is no exercise at position " .. tostring(index) .. ".", vim.log.levels.ERROR)
    return
  end
  if check_running then
    notify("A course check is already running.", vim.log.levels.WARN)
    return
  end

  check_running = true
  ctx.state.current = index
  save(ctx)
  notify("Preparing to verify " .. exercise.chapter .. "/" .. exercise.name .. "…")
  bootstrap.ensure_runner(config, function(ready, err)
    if not ready then
      check_running = false
      notify(err, vim.log.levels.ERROR)
      return
    end
    notify("Verifying " .. exercise.chapter .. "/" .. exercise.name .. "…")
    run_check(ctx, exercise, index)
  end)
end

local function open_dashboard(ctx)
  ui.dashboard(ctx.exercises, ctx.state, {
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

local function find_todos(ctx, index)
  local exercise = ctx.exercises[index]
  if not exercise then
    notify("There is no exercise at position " .. tostring(index) .. ".", vim.log.levels.ERROR)
    return
  end

  local source_dir = vim.fs.joinpath(exercise.dir, "src")
  local files = vim.fn.globpath(source_dir, "*.rs", false, true)
  local seen = {}
  for _, file in ipairs(files) do
    seen[file] = true
  end
  for _, file in ipairs(vim.fn.globpath(source_dir, "**/*.rs", false, true)) do
    if not seen[file] then
      files[#files + 1] = file
      seen[file] = true
    end
  end
  local items = {}
  for _, file in ipairs(files) do
    for line_number, line in ipairs(vim.fn.readfile(file)) do
      if line:find("TODO", 1, true) or line:find("todo!(", 1, true) then
        items[#items + 1] = {
          filename = file,
          lnum = line_number,
          col = 1,
          text = vim.trim(line),
        }
      end
    end
  end

  vim.fn.setqflist({}, " ", {
    title = "Rust 100 TODOs · " .. exercise.chapter .. "/" .. exercise.name,
    items = items,
  })
  if #items == 0 then
    notify("No TODO markers found in this exercise.")
    return
  end
  vim.cmd("copen")
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.health()
  local lines = { "Rust 100 health" }
  for _, command in ipairs({ "git", "cargo", "rustc" }) do
    local status = vim.fn.executable(command) == 1 and "available" or "missing"
    lines[#lines + 1] = string.format("%s: %s", command, status)
  end
  local runner_status = "missing"
  if bootstrap.runner_available() then
    runner_status = "available"
  elseif config.auto_setup and vim.fn.executable("cargo") == 1 and vim.fn.executable("rustc") == 1 then
    runner_status = "will install automatically"
  end
  lines[#lines + 1] = string.format("wr: %s", runner_status)
  lines[#lines + 1] = string.format("rust-analyzer: %s (optional)", vim.fn.executable("rust-analyzer") == 1 and "available" or "missing")

  local root, target = bootstrap.course_target(config)
  if root then
    lines[#lines + 1] = "course: " .. root
  elseif config.auto_setup then
    lines[#lines + 1] = "course: will download to " .. target
  else
    lines[#lines + 1] = "course: not found"
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Rust 100 health" })
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
    notify("Unknown action. Use :Rust100 with no arguments to open the course panel.", vim.log.levels.ERROR)
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
    notify("Unknown action. Use :Rust100 with no arguments to open the course panel.", vim.log.levels.ERROR)
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
