local utils = require "telescope.utils"
local Path = require "plenary.path"
local make_entry = {}

local handle_entry_index = function(opts, t, k)
    local override = ((opts or {}).entry_index or {})[k]
    if not override then
      return
    end
  
    local val, save = override(t, opts)
    if save then
      rawset(t, k, val)
    end
    return val
end
  
do
    local lookup_keys = {
      value = 1,
      ordinal = 1,
    }
  
    local parse_without_col = function(t)
      local _, _, filename, lnum, text = string.find(t.value, [[(..-):(%d+):(.*)]])
  
      local ok
      ok, lnum = pcall(tonumber, lnum)
      if not ok then
        lnum = nil
      end
  
      t.filename = filename
      t.lnum = lnum
      t.col = nil
      t.text = text
  
      return { filename, lnum, nil, text }
    end
  
    function make_entry.gen_from_vimgrep(opts)
      opts = opts or {}
  
      local mt_vimgrep_entry
      local parse = parse_without_col
  
      local disable_devicons = opts.disable_devicons
      local disable_coordinates = opts.disable_coordinates
      local only_sort_text = opts.only_sort_text
  
      local execute_keys = {
        path = function(t)
          if Path:new(t.filename):is_absolute() then
            return t.filename, false
          else
            return Path:new({ t.cwd, t.filename }):absolute(), false
          end
        end,
  
        filename = function(t)
          return parse(t)[1], true
        end,
  
        lnum = function(t)
          return parse(t)[2], true
        end,
  
        col = function(t)
          return parse(t)[3], true
        end,
  
        text = function(t)
          return parse(t)[4], true
        end,
      }
  
      -- For text search only, the ordinal value is actually the text.
      if only_sort_text then
        execute_keys.ordinal = function(t)
          return t.text
        end
      end
  
      local display_string = "%s%s%s"
  
      mt_vimgrep_entry = {
        cwd = utils.path_expand(opts.cwd or vim.loop.cwd()),
  
        display = function(entry)
          if Path.path.sep == "\\" then
            entry.filename = string.gsub(entry.filename, "/", "\\")
          end
          local display_filename, path_style = utils.transform_path(opts, entry.filename)
  
          local coordinates = ":"
          if not disable_coordinates then
            if entry.lnum then
              if entry.col then
                coordinates = string.format(":%s:%s:", entry.lnum, entry.col)
              else
                coordinates = string.format(":%s:", entry.lnum)
              end
            end
          end
  
          local display, hl_group, icon = utils.transform_devicons(
            entry.filename,
            string.format(display_string, display_filename, coordinates, entry.text),
            disable_devicons
          )
  
          if hl_group then
            local style = { { { 0, #icon }, hl_group } }
            style = utils.merge_styles(style, path_style, #icon + 1)
            return display, style
          else
            return display, path_style
          end
        end,
  
        __index = function(t, k)
          local override = handle_entry_index(opts, t, k)
          if override then
            return override
          end
  
          local raw = rawget(mt_vimgrep_entry, k)
          if raw then
            return raw
          end
  
          local executor = rawget(execute_keys, k)
          if executor then
            local val, save = executor(t)
            if save then
              rawset(t, k, val)
            end
            return val
          end
  
          return rawget(t, rawget(lookup_keys, k))
        end,
      }
  
      return function(line)
        return setmetatable({ line }, mt_vimgrep_entry)
      end
    end
end

return make_entry