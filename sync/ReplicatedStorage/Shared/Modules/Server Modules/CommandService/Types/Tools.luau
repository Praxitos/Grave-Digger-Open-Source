local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CmdrUtil = require(script.Parent.Parent.Shared.Util)

local ToolClasses = ReplicatedStorage.Shared.Library.Classes.ToolClasses
local GunClasses = ReplicatedStorage.Shared.Library.Classes.GunClasses

-- collect all class modules
local function getClasses()
	local list = {}

	for _, child in ipairs(ToolClasses:GetChildren()) do
		if child:IsA("ModuleScript") and not child:GetAttribute("UnListAble") then
			table.insert(list, child.Name)
		end
	end

	for _, child in ipairs(GunClasses:GetChildren()) do
		if child:IsA("ModuleScript") and not child:GetAttribute("UnListAble") then
			table.insert(list, child.Name)
		end
	end

	return list
end

local classType = {
	Transform = function(text)
		local classList = getClasses()
		local findClass = CmdrUtil.MakeFuzzyFinder(classList)

		return findClass(text)
	end;

	Validate = function(classes)
		return #classes > 0, "No class with that name found."
	end;

		Autocomplete = function(classes)
		return classes
	end;


	Parse = function(classes)
		return classes[1]
	end;
}

-- listable version
local classesType = {
	Listable = true;
	Transform = classType.Transform;
	Validate = classType.Validate;
	Autocomplete = classType.Autocomplete;


	Parse = function(classes)
		return classes -- classes are string names
	end;
}

return function(cmdr)
	cmdr:RegisterType("class", classType)
	cmdr:RegisterType("classes", classesType)
end

