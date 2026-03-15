--!strict
local module = {}

local Players = game:GetService("Players")

function module.start_module()
	print("PlayerService: Starting")
	Players.PlayerAdded:Connect(function(player: Player)
		local player_data_folder = Instance.new("Folder")
		player_data_folder.Name = "GameData"
		player_data_folder.Parent = player
		print("PlayerService: Created GameData folder for", player.Name)
	end)
end

return module
