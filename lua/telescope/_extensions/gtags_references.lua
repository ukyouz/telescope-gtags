local module = require("gtags_module")

return require("telescope").register_extension {
    setup = function(ext_config, cfg)
        -- access extension config and user config
        module.setup_env(ext_config)
    end,
    exports = {
        gtags_references = module.run_references_picker,
    },
}
