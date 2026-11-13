local M = {}

local function join(...)
  return vim.fs.joinpath(...)
end

local function normalize(path)
  local absolute = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  absolute = vim.fs.normalize(absolute)
  if #absolute > 1 then
    absolute = absolute:gsub("[/\\]+$", "")
  end
  return absolute
end

local function stat(path)
  return vim.uv.fs_stat(path)
end

local function is_directory(path)
  local info = stat(path)
  return info ~= nil and info.type == "directory"
end

local function is_course_root(path)
  return stat(join(path, ".wr.toml")) ~= nil
    and stat(join(path, ".git")) ~= nil
    and is_directory(join(path, "exercises"))
    and stat(join(path, "book", "src", "SUMMARY.md")) ~= nil
end

function M.normalize(path)
  return normalize(path)
end

function M.find_root(path)
  path = path or vim.fn.getcwd()
  if path:match("^[%w+.-]+://") then
    path = vim.fn.getcwd()
  end

  local cursor = normalize(path)
  if not is_directory(cursor) then
    cursor = vim.fs.dirname(cursor)
  end

  while cursor and cursor ~= "" do
    if is_course_root(cursor) then
      return cursor
    end

    local parent = vim.fs.dirname(cursor)
    if parent == cursor then
      break
    end
    cursor = parent
  end

  return nil
end

local function source_file(exercise_dir)
  local candidates = {
    join(exercise_dir, "src", "lib.rs"),
    join(exercise_dir, "src", "main.rs"),
  }

  for _, candidate in ipairs(candidates) do
    if stat(candidate) then
      return candidate
    end
  end

  local rust_files = vim.fn.globpath(join(exercise_dir, "src"), "*.rs", false, true)
  table.sort(rust_files)
  if rust_files[1] then
    return normalize(rust_files[1])
  end

  return join(exercise_dir, "Cargo.toml")
end

function M.load(root)
  local summary_path = join(root, "book", "src", "SUMMARY.md")
  if not stat(summary_path) then
    return nil, "The course index was not found at " .. summary_path
  end
  local ok, summary = pcall(vim.fn.readfile, summary_path)
  if not ok then
    return nil, "The course index could not be read at " .. summary_path
  end

  local exercises = {}
  for _, line in ipairs(summary) do
    local relative_lesson = line:match("%(([^)]+%.md)%)")
    local title = line:match("%[([^%]]+)%]")
    local chapter, name
    if relative_lesson then
      chapter, name = relative_lesson:match("^([^/]+)/([^/]+)%.md$")
    end

    if chapter and name then
      local exercise_dir = join(root, "exercises", chapter, name)
      local lesson_path = join(root, "book", "src", relative_lesson)
      local manifest = join(exercise_dir, "Cargo.toml")

      if stat(lesson_path) and stat(manifest) then
        exercises[#exercises + 1] = {
          chapter = chapter,
          name = name,
          title = title or name,
          id = chapter .. "/" .. name,
          lesson = lesson_path,
          dir = exercise_dir,
          source = source_file(exercise_dir),
        }
      end
    end
  end

  if #exercises == 0 then
    return nil, "No course exercises were found from book/src/SUMMARY.md"
  end

  return exercises
end

function M.index_for_path(exercises, path)
  if not path or path == "" or path:match("^[%w+.-]+://") then
    return nil
  end

  path = normalize(path)
  local separator = package.config:sub(1, 1)

  for index, exercise in ipairs(exercises) do
    local exercise_dir = normalize(exercise.dir)
    local prefix = exercise_dir .. separator
    if path == normalize(exercise.lesson) or path == exercise_dir or path:sub(1, #prefix) == prefix then
      return index
    end
  end

  return nil
end

return M
