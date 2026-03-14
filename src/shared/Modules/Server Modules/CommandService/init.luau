local module = {}

local cmdr_module = require(script.Cmdr)

function module.start_module()
	cmdr_module:RegisterCommandsIn(script.Commands)
	cmdr_module:RegisterHooksIn(script.Hooks)
	cmdr_module:RegisterTypesIn(script.Types)
end

return module
