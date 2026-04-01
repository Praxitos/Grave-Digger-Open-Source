local module = {}
local LocalPlayer = game:GetService("Players").LocalPlayer
local GameData = LocalPlayer:WaitForChild("GameData")
local Accessory_Folder = GameData:WaitForChild("Accessorys")
local Holster_Folder = Accessory_Folder:WaitForChild("Holsters")
local ToolHolster_Folder = game:GetService("ReplicatedStorage").Shared.Assets.Guns.Holsters:FindFirstChild("Tool Holsters")
local GunClasses = game:GetService("ReplicatedStorage").Shared.Library.Classes.GunClasses
local ToolClasses = game:GetService("ReplicatedStorage").Shared.Library.Classes.ToolClasses
local inventory_service = require(script.Parent.InventoryService)
local Util_Module = require(script.Parent.Parent.Parent.Library.Util)

module.RegisteredTools = {}

local function connect_backpack(backpack)
	backpack.ChildAdded:Connect(function(child)
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
		local instance = class.new({ name = child.Name })
		instance:on_give(child)
		module.RegisteredTools[child.Name] = instance
		inventory_service.assign_tool(module.RegisteredTools[child.Name])
		print("Finished registration for tool...", child.Name)
	end)

	backpack.ChildRemoved:Connect(function(child)
		if not child:IsA("Tool") then return end
		local instance = module.RegisteredTools[child.Name]
		if not instance then return end
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(child.Name) then
			return
		end
		inventory_service.remove_tool(module.RegisteredTools[child.Name])
		module.RegisteredTools[child.Name] = nil
	end)
end

function module.start_module()
	-- connect to the current backpack
	connect_backpack(LocalPlayer:WaitForChild("Backpack"))

	LocalPlayer.CharacterAdded:Connect(function()
		module.RegisteredTools = {}
		-- re-grab the fresh backpack and reconnect
		connect_backpack(LocalPlayer:WaitForChild("Backpack"))
	end)
end

return module