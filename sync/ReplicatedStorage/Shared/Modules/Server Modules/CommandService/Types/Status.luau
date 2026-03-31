local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CmdrUtil = require(script.Parent.Parent.Shared.Util)

local StatusClasses = ReplicatedStorage.Shared.Library.Classes.StatusClasses

-- collect all status modules
local function getstatuses()
	local list = {}

	for _, child in ipairs(StatusClasses:GetChildren()) do
		if child:IsA("ModuleScript") and not child:GetAttribute("UnListAble") then
			table.insert(list, child.Name)
		end
	end

	return list
end

local statusType = {
	Transform = function(text)
		local statusList = getstatuses()
		local findstatus = CmdrUtil.MakeFuzzyFinder(statusList)

		return findstatus(text)
	end;

	Validate = function(statuses)
		return #statuses > 0, "No status with that name found."
	end;

		Autocomplete = function(statuses)
		return statuses
	end;


	Parse = function(statuses)
		return statuses[1]
	end;
}

-- listable version
local statusesType = {
	Listable = true;
	Transform = statusType.Transform;
	Validate = statusType.Validate;
	Autocomplete = statusType.Autocomplete;


	Parse = function(statuses)
		return statuses -- statuses are string names
	end;
}

return function(cmdr)
	cmdr:RegisterType("status", statusType)
	cmdr:RegisterType("statuses", statusesType)
end

