local module = {}

local LocalPlayer = game:GetService("Players").LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local GameData = LocalPlayer:WaitForChild("GameData")
local Accessory_Folder = GameData:WaitForChild("Accessorys")
local Holster_Folder = Accessory_Folder:WaitForChild("Holsters")
local ToolHolster_Folder = game:GetService("ReplicatedStorage").Shared.Assets.Holsters:FindFirstChild("Tool Holsters")

local GunClasses = game:GetService("ReplicatedStorage").Shared.Library.Classes.GunClasses
local ToolClasses = game:GetService("ReplicatedStorage").Shared.Library.Classes.ToolClasses

local Util_Module = require(script.Parent.Parent.Parent.Library.Util)

module.RegisteredTools = {}

-- // Internal listeners
module._registration_added_listeners = {}
module._registration_removed_listeners = {}

-- // Public API

function module.on_registration_added(func)
	table.insert(module._registration_added_listeners, func)

	-- return disconnect function
	return function()
		local index = table.find(module._registration_added_listeners, func)
		if index then
			table.remove(module._registration_added_listeners, index)
		end
	end
end

function module.on_registration_removed(func)
	table.insert(module._registration_removed_listeners, func)

	return function()
		local index = table.find(module._registration_removed_listeners, func)
		if index then
			table.remove(module._registration_removed_listeners, index)
		end
	end
end

-- // Internal dispatchers

local function fire_added(instance, tool)
	for _, callback in ipairs(module._registration_added_listeners) do
		task.spawn(callback, instance, tool)
	end
end

local function fire_removed(instance, tool)
	for _, callback in ipairs(module._registration_removed_listeners) do
		task.spawn(callback, instance, tool)
	end
end

-- // Main

function module.start_module()

	Backpack.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end
		if module.RegisteredTools[child.Name] then return end	

		local moduleScript =
			GunClasses:FindFirstChild(child.Name, true)
			or ToolClasses:FindFirstChild(child.Name, true)

		if not moduleScript then
			warn("ToolService: No class found for item", child.Name)
			return
		end

		local class = require(moduleScript)

		local instance = class.new({
			name = child.Name
		})

		instance:on_give(child)

		module.RegisteredTools[child.Name] = instance

		-- Fire event AFTER full initialization
		fire_added(instance, child)
	end)

	Backpack.ChildRemoved:Connect(function(child)
		if not child:IsA("Tool") then return end

		local instance = module.RegisteredTools[child.Name]
		if not instance then return end

		-- ignore if equipped (still in character)
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(child.Name) then
			return
		end

		module.RegisteredTools[child.Name] = nil

		-- Fire removal event
		fire_removed(instance, child)
	end)

	-- // Holster system (unchanged, just cleaned slightly)
	Holster_Folder.ChildAdded:Connect(function(child)
		local reference = ToolHolster_Folder and ToolHolster_Folder:FindFirstChild(child.Name)
		if not reference then
			warn("ToolService: No holster reference found for item", child.Name)
			return
		end

		local primary_part = reference.PrimaryPart
		if not primary_part then
			warn("ToolService: No primary part found for holster", child.Name)
			return
		end

		local body_part_name = string.split(primary_part.Name, "_")[2]
		local character = LocalPlayer.Character

		if not character or not character:FindFirstChild(body_part_name) then
			warn("ToolService: No corresponding body part found for holster", child.Name)
			return
		end

		local clone = reference:Clone()

		Util_Module.quick_weld(
			clone.PrimaryPart,
			character[body_part_name],
			clone,
			child.Name .. "_Weld"
		)

		clone.Parent = character.CharacterData.Rendered_Holsters
	end)
end

return module