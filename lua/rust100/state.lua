local M = {}

local function state_file(root)
  local directory = vim.fs.joinpath(vim.fn.stdpath("state"), "rust100")
  vim.fn.mkdir(directory, "p")
  return vim.fs.joinpath(directory, vim.fn.sha256(root) .. ".json")
end

function M.load(root, exercises)
  local total = #exercises
  local path = state_file(root)
  local lines = vim.fn.readfile(path)
  if #lines > 0 then
    local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
    if ok and type(decoded) == "table" and decoded.root == root then
      local current
      if type(decoded.current_id) == "string" then
        for index, exercise in ipairs(exercises) do
          if exercise.id == decoded.current_id then
            current = index
            break
          end
        end
      end
      current = current or tonumber(decoded.current) or 1
      decoded.current = math.max(1, math.min(total, math.floor(current)))
      decoded.current_id = exercises[decoded.current].id
      decoded.completed = type(decoded.completed) == "table" and decoded.completed or {}
      return decoded, path
    end
  end

  return {
    version = 1,
    root = root,
    current = 1,
    current_id = exercises[1].id,
    completed = {},
  }, path
end

function M.save(state, path)
  local ok, encoded = pcall(vim.json.encode, state)
  if not ok then
    return false, encoded
  end

  local result = vim.fn.writefile({ encoded }, path)
  if result ~= 0 then
    return false, "Could not write course state to " .. path
  end

  return true
end

function M.completed_count(state, exercises)
  local count = 0
  for _, exercise in ipairs(exercises) do
    if state.completed[exercise.id] == true then
      count = count + 1
    end
  end
  return count
end

return M
