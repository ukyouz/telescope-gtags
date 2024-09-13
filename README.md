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
},
```

#### Optional Key-Binding

```lua
{
    "ukyouz/telescope-gtags",
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