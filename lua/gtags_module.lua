local action_set = require "telescope.actions.set"
local action_state = require "telescope.actions.state"
local conf = require("telescope.config").values
local entry_display = require "telescope.pickers.entry_display"
local finders = require "telescope.finders"
local telescope_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
local previewers = require "telescope.previewers"
local utils = require "telescope.utils"
local entry_maker = require "entry_maker"
local flatten = utils.flatten
local hash = require "hash"


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

local M = {}

local get_dbpath = function()
    local pwd = vim.fn.getcwd()
    local path, path_style = utils.transform_path(
        {
            path_display = {'absolute', 'shorten'}
        },
        pwd
    )
    local sha = string.sub(hash.sha1(path), 0, 8)
    return pwd, path:gsub("\\", "-"):gsub("/", "-") .. '-' .. sha
end

local OPTS = {
    storeInProjectFolder = true,
    dbPath = vim.fn.stdpath('data') .. '/gtags/',
}

M.setup = function(opts)
    for k, v in pairs(opts) do
        OPTS[k] = v
    end
    -- print(vim.inspect(OPTS))
end


M.setup_env = function()
    local pwd, folder = get_dbpath()
    if vim.F.if_nil(OPTS.storeInProjectFolder) then
        return pwd, pwd
    end
    -- print(OPTS.dbPath .. folder)
    vim.env.GTAGSROOT = pwd
    vim.env.GTAGSDBPATH = OPTS.dbPath .. folder
    return pwd, OPTS.dbPath .. folder
end


-- our picker function: colors
M.run_symbols_picker = function(opts)
    if vim.fn.executable "global" == 0 then
        utils.notify("gtags", {
            msg = "You need to install gtags and create a GTAGS file to use this picker",
            level = "ERROR",
        })
        return
    end
    M.setup_env(opts)

    opts.bufnr = 0

    pickers.new(opts, {
        prompt_title = "GTAGS Symbols",
        previewer = previewers.ctags.new(opts),
        finder = finders.new_job(function(prompt)
            if not prompt or prompt == "" then
                prompt = opts.query
                if prompt == "" or prompt == nil then
                    return nil
                end
            end

            local chars = {}
            prompt:gsub(".", function(c) table.insert(chars, c) end)

            local query = table.concat(chars, ".*") .. ".*"
            -- print(vim.inspect(query))

            return { "global", "-t", "-i", query, "--result=ctags"}
        end, opts.entry_maker or telescope_entry.gen_from_ctags(opts), opts.max_results, opts.cwd),
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

M.run_buffer_symbols_picker = function(opts)
    local curernt_file = vim.api.nvim_buf_get_name(0)

    local args = {
        "global",
        "-f",
        curernt_file,
        "--result=ctags",
    }

    opts.bufnr = 0
    -- set __inverted to use parse_without_col function in make_entry.lua
    opts.__inverted = true
    opts.entry_maker = opts.entry_maker or telescope_entry.gen_from_ctags(opts)
    pickers.new(opts, {
        prompt_title = "GTAGS Buffer Tags",
        finder = finders.new_oneshot_job(args, opts),
        previewer = conf.grep_previewer(opts),
        sorter = conf.generic_sorter({opts}),
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
    }):find()
end

M.run_definitions_picker = function(opts)
    if vim.fn.executable "global" == 0 then
        utils.notify("gtags", {
            msg = "You need to install gtags and create a GTAGS file to use this picker",
            level = "ERROR",
        })
        return
    end

    opts.bufnr = 0
    -- set __inverted to use parse_without_col function in make_entry.lua
    opts.__inverted = true

    local query = vim.fn.expand(opts.query or "<cword>")
    local handle = io.popen("global -t " .. query .. " --result=ctags")
    local result = handle:read("*a")
    handle:close()
    local items = {}
    for s in result:gmatch("[^\r\n]+") do
        table.insert(items, s)
    end

    local entry_maker = opts.entry_maker or telescope_entry.gen_from_ctags(opts)

    if #items == 1 and opts.jump_type ~= "never" then
        local curr_filepath = vim.api.nvim_buf_get_name(opts.bufnr)
        local item = entry_maker(items[1])
        if curr_filepath ~= item.filename then
            local cmd = "edit"
            if opts.jump_type == "tab" then
                cmd = "tabedit"
            elseif opts.jump_type == "split" then
                cmd = "new"
            elseif opts.jump_type == "vsplit" then
                cmd = "vnew"
            elseif opts.jump_type == "tab drop" then
                cmd = "tab drop"
            end
            if cmd then
                vim.cmd(string.format("%s %s", cmd, item.filename))
            end
        end

        vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
    else
        pickers.new(opts, {
            prompt_title = "GTAGS Definitions - " .. query,
            previewer = previewers.ctags.new(opts),
            finder = finders.new_table {
                results = items,
                entry_maker = entry_maker,
            },
            sorter = conf.generic_sorter({opts}),
            push_cursor_on_edit = true,
            push_tagstack_on_edit = true,
        }):find()
    end
end

local get_current_word = function(opts)
    local visual = vim.fn.mode() == "v"
    local word
    if visual == true then
        local saved_reg = vim.fn.getreg "v"
        vim.cmd [[noautocmd sil norm! "vy]]
        local sele = vim.fn.getreg "v"
        vim.fn.setreg("v", saved_reg)
        word = vim.F.if_nil(opts.search, sele)
    else
        word = vim.F.if_nil(opts.search, vim.fn.expand "<cword>")
    end
    return word
end

M.run_references_picker = function(opts)
    local search = get_current_word(opts)

    local args = {
        "global",
        "-r",
        search,
        "--result=grep",
    }

    opts.entry_maker = opts.entry_maker or entry_maker.gen_from_vimgrep(opts)
    pickers.new(opts, {
        prompt_title = "GTAGS References - " .. search,
        finder = finders.new_oneshot_job(args, opts),
        previewer = conf.grep_previewer(opts),
        sorter = conf.generic_sorter({opts}),
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
    }):find()
end

M.run_symbol_usages_picker = function(opts)
    local search = get_current_word(opts)

    local args = {
        "global",
        "-s",
        "-e",
        search,
        "--literal",
        "--result=grep",
    }

    opts.entry_maker = opts.entry_maker or entry_maker.gen_from_vimgrep(opts)
    pickers.new(opts, {
        prompt_title = "GTAGS Symbol - " .. search,
        finder = finders.new_oneshot_job(args, opts),
        previewer = conf.grep_previewer(opts),
        sorter = conf.generic_sorter({opts}),
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
    }):find()
end

M.run_grep_picker = function(opts)
    local search = get_current_word(opts)

    local args = {
        "global",
        "-g",
        search,
        "--literal",
        "--result=grep",
    }

    opts.entry_maker = opts.entry_maker or entry_maker.gen_from_vimgrep(opts)
    pickers.new(opts, {
        prompt_title = "Global Grep - " .. search,
        finder = finders.new_oneshot_job(args, opts),
        previewer = conf.grep_previewer(opts),
        sorter = conf.generic_sorter({opts}),
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
    }):find()
end

return M
