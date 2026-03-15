--!strict
local module = {}

local Players = game:GetService("Players")


local function give_item(player)
	local mining_pickaxe = game:GetService("ReplicatedStorage").Shared.Assets.Tools.Mining:Clone()
	mining_pickaxe.Parent = player.Backpack
	print("PlayerService: Gave mining pickaxe to", player.Name)
end

local function setup_player(player: Player)
	local player_data_folder = Instance.new("Folder")
	player_data_folder.Name = "GameData"
	player_data_folder.Parent = player

	give_item(player)
	print("PlayerService: Set up player", player.Name)
end


function module.start_module()
	for _, player in ipairs(Players:GetPlayers()) do
		setup_player(player)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		setup_player(player)
	end)
end

return module
