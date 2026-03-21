--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Logger = require(ReplicatedStorage.Shared.Library.Logger)("ServerStarter")

local modules_folder = ReplicatedStorage.Shared.Modules["Server Modules"]

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

game.StarterPlayer.EnableMouseLockOption = false
