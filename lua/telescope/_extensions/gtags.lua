local module = require("gtags_module")

return require("telescope").register_extension {
    -- setup = function(ext_config, config)
    --   -- access extension config and user config
    -- end,
    exports = {
        gtags = module.run_symbols_picker,
    },
}
