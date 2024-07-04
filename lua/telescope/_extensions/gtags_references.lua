local module = require("gtags_module")

return require("telescope").register_extension {
    -- setup = function(ext_config, config)
    --   -- access extension config and user config
    -- end,
    exports = {
        gtags_references = module.run_references_picker,
    },
}
