--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
-- local Logger = require(ReplicatedStorage.Shared.Library.Logger)("ClientStarter")

local modules_folder = ReplicatedStorage.Shared.Modules["Client Modules"]

local function start_modules()
	print("Starting client modules")
	for _, child in ipairs(modules_folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, mod = pcall(require, child)
			if ok and mod.start_module then
				mod:start_module()
			else
				warn("Failed to load module", child.Name)
			end
		end
	end
end

local function disable_base_setups()
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.AutoRotate = false
	end)
end

start_modules()
disable_base_setups()
