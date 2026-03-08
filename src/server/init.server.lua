local player_service    = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")

-- // Primary Testing
player_service.PlayerAdded:Connect(function(player)
    print(player.Name)
end)


-- // startup test
local modules_folder = replicated_storage.Shared.Modules.TrueHello
require(modules_folder)