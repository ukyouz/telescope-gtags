# telescope-gtags
Telescope.nvim extension for global tag support

## Installtion

### Lazy.nvim

#### Basic Config

```lua
{
    "ukyouz/telescope-gtags",
    dependencies = {
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require('telescope').load_extension('gtags')
    end,
    -- ...optional configs, see below
},
```

#### Optional Key-Binding

```lua
{
    -- ...
    keys = {
        {
            "<leader>tg", "<cmd>:Telescope gtags file_encoding=cp932<cr>",
            desc = "Telescope Gtag symbols",
        },
        {
            "<leader>td", "<cmd>:Telescope gtags_definitions file_encoding=cp932 initial_mode=normal<cr>",
            desc = "Telescope Definitions (Gtags)",
        },
        {
            "<leader>tr", "<cmd>:let @/=expand('<cword>') | set hlsearch | Telescope gtags_references file_encoding=cp932 initial_mode=normal<cr>",
            desc = "Telescope References (Gtags)",
        },
        {
            "<leader>ts", "<cmd>:let @/=expand('<cword>') | set hlsearch | Telescope gtags_symbol_usages file_encoding=cp932 initial_mode=normal<cr>",
            desc = "Telescope Symbols (Gtags)",
        },
        {
            "<leader>tt", "<cmd>:Telescope gtags_buffer_symbols file_encoding=cp932<cr>",
            desc = "Telescope buffer Tags (Gtags)",
        },
        {
            "<S-F5>", function()
                local cmd = "git ls-files | gtags --incremental --file -"
                print(vim.fn.printf("running [%s]...", cmd))
                vim.fn.jobstart(
                    cmd,
                    {
                        on_exit = function(jobid, exit_code, evt_type)
                            if exit_code == 0 then
                                print(vim.fn.printf("[%s] done.", cmd))
                            else
                                print(vim.fn.printf("[%s] Error!", cmd))
                            end
                        end,
                        on_stdout = function(cid, data, name)
                            print(data[1])
                        end,
                        on_stderr = function(cid, data, name)
                            if data[1] ~= "" then
                                print("Error:" .. data[1])
                            end
                        end,
                    }
                )
            end,
            desc = "Generate GTAGS files",
        },
    },
    -- ...
},
```

#### Store gtags db separately

The plugin default run gtags command under project root folder, thus gtags databases also stored under same directory. However, if you want to collect those db files in other directory, you can disable `storeInProjectFolder` options and set any `dbPath` directory as you want.

You need to make the db folder and move the db files by youself after db generation, see the following example.

```lua
{
    -- ...
    opts = {
        storeInProjectFolder = false,  -- default is true
        dbPath = vim.fn.stdpath("data") .. "/gtags",  -- default value
    },
    keys = {
        {
            -- ...
            "<S-F5>", function()
                local pwd, dbpath = require('telescope-gtags').setup_env()
                local cmd = "git ls-files --recurse-submodules | gtags --incremental --file -"
                -- `-p` only works on linux
                os.execute("mkdir -p " .. dbpath)
                print(vim.fn.printf("running [%s]...", cmd))
                vim.fn.jobstart(
                    cmd,
                    {
                        on_exit = function(jobid, exit_code, evt_type)
                            os.remove(dbpath .. "/GPATH")
                            os.remove(dbpath .. "/GRTAGS")
                            os.remove(dbpath .. "/GTAGS")
                            if exit_code == 0 then
                                print(vim.fn.printf("[%s] done.", cmd))
                                os.rename("GPATH", dbpath .."/GPATH")
                                os.rename("GRTAGS", dbpath .."/GRTAGS")
                                os.rename("GTAGS", dbpath .."/GTAGS")
                            else
                                print(vim.fn.printf("[%s] Error %d! Tag files are removed.", cmd, exit_code))
                            end
                        end,
                        on_stdout = function(cid, data, name)
                            print(data[1])
                        end,
                        on_stderr = function(cid, data, name)
                            if data[1] ~= "" then
                                print("Error:" .. data[1])
                            end
                        end,
                    }
                )
            end,
        },
    },
}
```