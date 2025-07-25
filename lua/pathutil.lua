local M = {}

M.path_separator = "/"
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1
if M.is_windows == true then
  M.path_separator = "\\"
end

---Split string into a table of strings using a separator.
---@param inputString string The string to split.
---@param sep string The separator to use.
---@return table table A table of strings.
M.split = function(inputString, sep)
  local fields = {}

  local pattern = string.format("([^%s]+)", sep)
  local _ = string.gsub(inputString, pattern, function(c)
    fields[#fields + 1] = c
  end)

  return fields
end

M.normalize = function(path)
    if M.path_separator == "\\" then
        return path:gsub("/", "\\")
    else
        return path:gsub("\\", "/")
    end
end

---Joins arbitrary number of paths together.
---@param ... string The paths to join.
---@return string
M.join = function(...)
  local args = {...}
  if #args == 0 then
    return ""
  end

  local all_parts = {}
--   if type(args[1]) =="string" and args[1]:sub(1, 1) == "\\" then
--     all_parts[1] = ""
--   end

  for _, arg in ipairs(args) do
    norm_path = M.normalize(arg)
    arg_parts = M.split(norm_path, M.path_separator)
    vim.list_extend(all_parts, arg_parts)
  end

  return table.concat(all_parts, M.path_separator)
end

return M