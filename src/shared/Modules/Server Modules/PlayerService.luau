--!strict
local module = {}

local Players = game:GetService("Players")

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

local function fetch_hair_accessories(player: Player)
	local humanoidDescription: HumanoidDescription = Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)

	local accessories = humanoidDescription:GetAccessories(true) -- true includes rigid accessories
	
	-- // get only hair accessories
	for _, accessory:Accessory in pairs(accessories) do
		if not accessory.AccessoryType.Name:find("Hair") then continue end
		print("Asset ID: " .. accessory.AssetId)
	end
end

local function setup_player(player: Player)
	setup_gamedata(player)

	player.CharacterAdded:Connect(function()
		setup_characterdata(player.Character)
	end)

	fetch_hair_accessories(player)
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
