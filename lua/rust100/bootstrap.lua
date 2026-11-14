local course = require("rust100.course")

local M = {}
local course_url = "https://github.com/mainmatter/100-exercises-to-learn-rust.git"
local course_installing = false
local course_waiters = {}
local runner_installing = false
local runner_waiters = {}

local function join(...)
  return vim.fs.joinpath(...)
end

local function data_root()
  return join(vim.fn.stdpath("data"), "rust100")
end

local function normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Rust 100" })
end

local function run_process(command, cwd, callback)
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

local function output(result)
  local message = vim.trim((result.stderr or "") .. "\n" .. (result.stdout or ""))
  if message == "" then
    return "El comando terminó sin mostrar detalles."
  end
  if #message > 1800 then
    return "…" .. message:sub(-1800)
  end
  return message
end

local function complete_course(root, err)
  local waiters = course_waiters
  course_waiters = {}
  course_installing = false
  for _, callback in ipairs(waiters) do
    callback(root, err)
  end
end

function M.course_target(config)
  if config.course_root and config.course_root ~= "" then
    local configured = normalize(config.course_root)
    return course.find_root(configured), configured
  end

  local root = course.find_root(vim.api.nvim_buf_get_name(0)) or course.find_root(vim.fn.getcwd())
  if root then
    return root
  end

  local fallback = join(data_root(), "course")
  return course.find_root(fallback), fallback
end

function M.ensure_course(config, callback)
  local root, target = M.course_target(config)
  if root then
    callback(root)
    return
  end

  if config.auto_setup == false then
    callback(nil, "No se encontró el curso. Activa auto_setup o define course_root.")
    return
  end

  if course_installing then
    course_waiters[#course_waiters + 1] = callback
    return
  end

  if vim.fn.executable("git") ~= 1 then
    callback(nil, "Se necesita Git para descargar el curso automáticamente.")
    return
  end

  local target_stat = vim.uv.fs_stat(target)
  if target_stat then
    if target_stat.type ~= "directory" then
      callback(nil, "La ruta del curso no es una carpeta: " .. target)
      return
    end
    local ok, iterator = pcall(vim.fs.dir, target)
    if not ok or iterator() ~= nil then
      callback(nil, "La carpeta de destino ya existe y no contiene el curso: " .. target)
      return
    end
  end

  local parent = vim.fs.dirname(target)
  vim.fn.mkdir(parent, "p")
  if not vim.uv.fs_stat(parent) then
    callback(nil, "No se pudo crear la carpeta del curso: " .. parent)
    return
  end

  course_installing = true
  course_waiters = { callback }
  notify("Descargando el curso oficial 100 Exercises…")
  run_process({ "git", "clone", course_url, target }, parent, function(result)
    if result.code ~= 0 then
      complete_course(nil, "No se pudo descargar el curso:\n" .. output(result))
      return
    end

    local cloned_root = course.find_root(target)
    if not cloned_root then
      complete_course(nil, "El repositorio descargado no tiene la estructura del curso 100 Exercises.")
      return
    end

    notify("Curso listo. Preparando el panel de estudio…")
    complete_course(cloned_root)
  end)
end

local function add_to_path(directory)
  local path_separator = package.config:sub(1, 1) == "\\" and ";" or ":"
  local current = vim.env.PATH or ""
  if not current:find(directory, 1, true) then
    vim.env.PATH = directory .. path_separator .. current
  end
end

local function runner_candidates()
  local binary_suffix = package.config:sub(1, 1) == "\\" and ".exe" or ""
  local cargo_home = vim.env.CARGO_HOME or vim.fn.expand("~/.cargo")
  local cargo_bin = join(cargo_home, "bin")
  local install_bin = join(data_root(), "toolchain", "bin")
  return {
    { bin = cargo_bin, executable = join(cargo_bin, "wr" .. binary_suffix) },
    { bin = install_bin, executable = join(install_bin, "wr" .. binary_suffix) },
  }
end

function M.runner_available()
  if vim.fn.executable("wr") == 1 then
    return true
  end

  for _, candidate in ipairs(runner_candidates()) do
    if vim.fn.executable(candidate.executable) == 1 then
      add_to_path(candidate.bin)
      return vim.fn.executable("wr") == 1
    end
  end

  return false
end

local function complete_runner(ready, err)
  local waiters = runner_waiters
  runner_waiters = {}
  runner_installing = false
  for _, callback in ipairs(waiters) do
    callback(ready, err)
  end
end

function M.ensure_runner(config, callback)
  if M.runner_available() then
    callback(true)
    return
  end

  if config.auto_setup == false then
    callback(false, "Falta `wr` y la instalación automática está desactivada.")
    return
  end

  if runner_installing then
    runner_waiters[#runner_waiters + 1] = callback
    return
  end

  if vim.fn.executable("cargo") ~= 1 then
    callback(false, "Se necesita Cargo para instalar el verificador automáticamente.")
    return
  end

  local install_root = join(data_root(), "toolchain")
  local parent = data_root()
  vim.fn.mkdir(parent, "p")
  if not vim.uv.fs_stat(parent) then
    callback(false, "No se pudo crear la carpeta de datos de Rust 100: " .. parent)
    return
  end

  runner_installing = true
  runner_waiters = { callback }
  notify("Instalando el verificador de ejercicios en segundo plano…")
  run_process({ "cargo", "install", "--locked", "--root", install_root, "workshop-runner" }, parent, function(result)
    if result.code == 0 and M.runner_available() then
      notify("Verificador instalado y listo.")
      complete_runner(true)
      return
    end

    complete_runner(false, "No se pudo instalar el verificador:\n" .. output(result))
  end)
end

return M
