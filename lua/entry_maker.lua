local utils = require "telescope.utils"
local entry_display = require "telescope.pickers.entry_display"
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
    
    function make_entry.gen_from_ctags(opts)
      opts = opts or {}
    
    
      local cwd = utils.path_expand(opts.cwd or vim.loop.cwd())
      local current_file = Path:new(vim.api.nvim_buf_get_name(opts.bufnr)):normalize(cwd)
    
      local display_items = {
    
        { remaining = true },
      }
    
      local idx = 1
      local hidden = utils.is_path_hidden(opts)
      if not hidden then
        table.insert(display_items, idx, { width = vim.F.if_nil(opts.fname_width, 30) })
        idx = idx + 1
      end
    
      if opts.show_line then
        table.insert(display_items, idx, { width = 30 })
      end
    
      local displayer = entry_display.create {
        separator = " │ ",
        items = display_items,
      }
    
      local make_display = function(entry)
        local display_path, path_style = utils.transform_path(opts, entry.filename)
    
        local scode
        if opts.show_line then
          scode = entry.scode
        end
    
        if hidden then
          return displayer {
            entry.tag,
            scode,
          }
        else
          return displayer {
            {
              display_path,
              function()
                return path_style
              end,
            },
            entry.tag,
    
            scode,
          }
        end
      end
    
      local mt = {}
      mt.__index = function(t, k)
        local override = handle_entry_index(opts, t, k)
        if override then
          return override
        end
    
        if k == "path" then
          local retpath = Path:new({ t.filename }):absolute()
          if not vim.loop.fs_access(retpath, "R") then
            retpath = t.filename
          end
          return retpath
        end
      end
    
      local current_file_cache = {}
      return function(line)
        if line == "" or line:sub(1, 1) == "!" then
          return nil
        end
    
        local tag, file, scode, lnum
        -- ctags gives us: 'tags\tfile\tsource'
        tag, file, scode = string.match(line, '([^\t]+)\t([^\t]+)\t/^?\t?(.*)/;"\t+.*')
        if not tag then
          -- hasktags gives us: 'tags\tfile\tlnum'
          tag, file, lnum = string.match(line, "([^\t]+)\t([^\t]+)\t(%d+).*")
        end
    
    
        if Path.path.sep == "\\" then
          file = string.gsub(file, "/", "\\")
        end
    
        if opts.only_current_file then
          if current_file_cache[file] == nil then
            current_file_cache[file] = Path:new(file):normalize(cwd) == current_file
          end
    
          if current_file_cache[file] == false then
            return nil
          end
        end
    
        local tag_entry = {}
        if opts.only_sort_tags then
          tag_entry.ordinal = tag
        else
          tag_entry.ordinal = file .. ": " .. tag
        end
    
        tag_entry.display = make_display
        tag_entry.scode = scode
        tag_entry.tag = tag
        tag_entry.filename = file
        tag_entry.col = 1
        tag_entry.lnum = lnum and tonumber(lnum) or 1
    
    
    
    
        return setmetatable(tag_entry, mt)
      end
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
            local style = {
              { { 0, #icon + #display_filename + 1 }, hl_group },
              { { #icon + #display_filename + 2, #icon + #display_filename + #coordinates }, "Number" },
            }
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