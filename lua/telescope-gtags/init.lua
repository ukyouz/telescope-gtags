local module = require("gtags_module")

return {
    setup = function(opts)
        module.setup(opts)
    end,
    setup_env = function()
        return module.setup_env()
    end
}
