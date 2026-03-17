--!strict
local module = {}

local Players = game:GetService("Players")


local function give_item(player)
	task.wait(3)
	local ItemsService = require(script.Parent:WaitForChild("ItemsService"))
	ItemsService.give_item(player, "Pickaxe")
end

local function setup_gamedata(player: Player)
	local player_data_folder = Instance.new("Folder")
	player_data_folder.Name = "GameData"
	player_data_folder.Parent = player

	local accessorys_folder = Instance.new("Folder")
	accessorys_folder.Name = "Accessorys"
	accessorys_folder.Parent = player_data_folder

	local holsters_folder = Instance.new("Folder")
	holsters_folder.Name = "Holsters"
	holsters_folder.Parent = accessorys_folder

	local hairs_folder = Instance.new("Folder")
	hairs_folder.Name = "Hairs"
	hairs_folder.Parent = accessorys_folder

	local hats_folder = Instance.new("Folder")
	hats_folder.Name = "Hats"
	hats_folder.Parent = accessorys_folder
end

local function setup_characterdata(character: Model)
	local folder = Instance.new("Folder")
	folder.Name = "CharacterData"
	folder.Parent = character

	local Holster_Folder = Instance.new("Folder")
	Holster_Folder.Name = "Rendered_Holsters"
	Holster_Folder.Parent = folder
end

local function setup_player(player: Player)
	setup_gamedata(player)

	player.CharacterAdded:Connect(function()
		give_item(player)
		setup_characterdata(player.Character)
	end)

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
