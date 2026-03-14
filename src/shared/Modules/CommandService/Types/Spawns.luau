local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(script.Parent.Parent.Shared.Util) -- your fuzzy/autocomplete utils

-- Folders
local ValuesFolder = ReplicatedStorage:WaitForChild("Values")
local VariablesFolder = ValuesFolder:WaitForChild("Variables")
local SpawningsFolder = VariablesFolder:WaitForChild("Spawnings")
local LocationsFolder = SpawningsFolder:WaitForChild("Locations")

-- Table to track spawn locations dynamically
local spawns_table = {}

-- Populate initial table
for _, child in ipairs(LocationsFolder:GetChildren()) do
	if child:IsA("Instance") and not string.find(child.Name, "Offset") then
		table.insert(spawns_table, child)
	end
end

-- Keep table up to date
LocationsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Instance") and not string.find(child.Name, "Offset") then
		table.insert(spawns_table, child)
	end
end)

LocationsFolder.ChildRemoved:Connect(function(child)
	if child:IsA("Instance") then
		for i, v in ipairs(spawns_table) do
			if v == child then
				table.remove(spawns_table, i)
				break
			end
		end
	end
end)

-- Single SpawnLocation type
local spawnLocationType = {
	Transform = function(text)
		if type(text) ~= "string" or text == "" then return {} end
		local findSpawn = Util.MakeFuzzyFinder(spawns_table)
		return findSpawn(text) -- returns array of matching Instances
	end;

	Validate = function(spawns)
		return #spawns > 0, "No spawn location found with that name."
	end;

	Autocomplete = function(spawns)
		return Util.GetNames(spawns)
	end;

	Parse = function(spawns)
		return spawns[1] -- single selection
	end;
}

-- Listable SpawnLocations type
local spawnLocationsType = {
	Listable = true;
	Transform = spawnLocationType.Transform;
	Validate = spawnLocationType.Validate;
	Autocomplete = spawnLocationType.Autocomplete;
	Parse = function(spawns)
		return spawns -- return all matches
	end;
}

-- Register types with Cmdr
return function(cmdr)
	cmdr:RegisterType("spawnlocation", spawnLocationType)
	cmdr:RegisterType("spawnlocations", Util.MakeListableType(spawnLocationType))
end
