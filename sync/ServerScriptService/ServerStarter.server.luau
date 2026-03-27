--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Logger = require(ReplicatedStorage.Shared.Library.Logger)("ServerStarter")

print("[ServerStarter] Starting server modules...")

local modules_folder = ReplicatedStorage.Shared.Modules["Server Modules"]

for _, child in ipairs(modules_folder:GetChildren()) do
	if child:IsA("ModuleScript") then
		print("[ServerStarter] Loading module: " .. child.Name)
		local ok, mod = pcall(require, child)
		if ok and mod.start_module then
			print("[ServerStarter] Starting module: " .. child.Name)
			mod:start_module()
		else
			warn("Failed to load module", child.Name)
		end
	end
end

print("[ServerStarter] All modules loaded")
game.StarterPlayer.EnableMouseLockOption = false
