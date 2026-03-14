local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(script.Parent.Parent.Shared.Util)

local ValuesFolder = ReplicatedStorage:WaitForChild("Values")
local VariablesFolder = ValuesFolder:WaitForChild("Variables")

-- Collect all ValueBase descendants
local function getVariables()
	local vars = {}

	for _, child in ipairs(VariablesFolder:GetDescendants()) do
		if child:IsA("ValueBase") then
			table.insert(vars, child)
		end
	end

	return vars
end

local variableType = {
	Transform = function(text)
		local varList = getVariables()
		local findVar = Util.MakeFuzzyFinder(varList)

		return findVar(text)
	end;

	Validate = function(vars)
		return #vars > 0, "No variable with that name could be found."
	end;

	Autocomplete = function(vars)
		-- turn list of instances into list of names
		return Util.GetNames(vars)
	end;

	Parse = function(vars)
		return vars[1] -- return the first match (Cmdr pattern)
	end;
}

-- Listable form: returns array of ValueBase objects
local variablesType = {
	Listable = true;
	Transform = variableType.Transform;
	Validate = variableType.Validate;
	Autocomplete = variableType.Autocomplete;

	Parse = function(vars)
		return vars -- listable already means multiple allowed
	end;
}

return function(cmdr)
	cmdr:RegisterType("variable", variableType)
	cmdr:RegisterType("variables", Util.MakeListableType(variableType))
end
