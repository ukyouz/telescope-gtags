# telescope-gtags
Telescope.nvim extension for global tag support

## Installtion

### Lazy.nvim

```lua
{
    "ukyouz/telescope-gtags",
    dependencies = {
        "nvim-telescope/telescope.nvim",
    },
    -- keys = {
    --     {
    --         "<leader>tg", "<cmd>:Telescope gtags<cr>",
    --         desc = "Telescope Gtag symbols",
    --     },
    -- },
    config = function()
        if H.has_plugin "telescope.nvim" then
            require('telescope').load_extension('gtags')
        end
    end,
},
```