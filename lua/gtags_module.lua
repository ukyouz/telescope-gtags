-- local stdlib = require "posix.stdlib"

local action_set = require "telescope.actions.set"
local action_state = require "telescope.actions.state"
local conf = require("telescope.config").values
local entry_display = require "telescope.pickers.entry_display"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
local previewers = require "telescope.previewers"
local utils = require "telescope.utils"
local flatten = utils.flatten

local M = {}

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

-- our picker function: colors
M.run_symbols_picker = function(opts)
    opts.bufnr = 0

    pickers.new(opts, {
        prompt_title = "GTAGS Symbols",
        previewer = previewers.ctags.new(opts),
        finder = finders.new_job(function(prompt)
            if not prompt or prompt == "" then
              return nil
            end

            local chars = {}
            prompt:gsub(".", function(c) table.insert(chars, c) end)

            local query = table.concat(chars, ".*") .. ".*"
            -- print(vim.inspect(query))

            return { "global", "-t", "-i", query, "--result=ctags"}
        end, opts.entry_maker or make_entry.gen_from_ctags(opts), opts.max_results, opts.cwd),
        sorter = conf.generic_sorter({opts}),
        attach_mappings = function()
            action_set.select:enhance {
              post = function()
                local selection = action_state.get_selected_entry()
                if not selection then
                  return
                end

                if selection.scode then
                  -- un-escape / then escape required
                  -- special chars for vim.fn.search()
                  -- ] ~ *
                  local scode = selection.scode:gsub([[\/]], "/"):gsub("[%]~*]", function(x)
                    return "\\" .. x
                  end)

                  vim.cmd "keepjumps norm! gg"
                  vim.fn.search(scode)
                  vim.cmd "norm! zz"
                else
                  vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
                end
              end,
            }
            return true
        end,
    }):find()
end

return M
