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

local escape_chars = function(string)
    return string.gsub(string, "[%(|%)|\\|%[|%]|%-|%{%}|%?|%+|%*|%^|%$|%.]", {
        ["\\"] = "\\\\",
        ["-"] = "\\-",
        ["("] = "\\(",
        [")"] = "\\)",
        ["["] = "\\[",
        ["]"] = "\\]",
        ["{"] = "\\{",
        ["}"] = "\\}",
        ["?"] = "\\?",
        ["+"] = "\\+",
        ["*"] = "\\*",
        ["^"] = "\\^",
        ["$"] = "\\$",
        ["."] = "\\.",
    })
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
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
    }):find()
end

M.run_references_picker = function(opts)
    local word
    local visual = vim.fn.mode() == "v"

    if visual == true then
        local saved_reg = vim.fn.getreg "v"
        vim.cmd [[noautocmd sil norm! "vy]]
        local sele = vim.fn.getreg "v"
        vim.fn.setreg("v", saved_reg)
        word = vim.F.if_nil(opts.search, sele)
    else
        word = vim.F.if_nil(opts.search, vim.fn.expand "<cword>")
    end
    local search = opts.use_regex and word or escape_chars(word)
    
    local args = {
        "global",
        "-r",
        search,
        "--result=grep",
    }
    
    -- set __inverted to use parse_without_col function in make_entry.lua
    opts.__inverted = true
    opts.entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts)
    pickers.new(opts, {
        prompt_title = "GTAGS References",
        finder = finders.new_oneshot_job(args, opts),
        previewer = conf.grep_previewer(opts),
        sorter = conf.generic_sorter({opts}),
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
    }):find()
end

return M
