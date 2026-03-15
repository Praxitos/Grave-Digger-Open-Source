local module = {}

local player_service = game:GetService("Players")

function module.start_module()
    player_service.PlayerAdded:Connect(function(player)
        local player_data_folder = Instance.new("Folder")
        player_data_folder.Name = "GameData"
        player_data_folder.Parent = player
    end)
end

return module