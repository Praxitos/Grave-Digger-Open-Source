--!strict
local module = {}

local Players = game:GetService("Players")

local Animations_Folder = game:GetService("ReplicatedStorage").Shared.Assets.Animations.Character.Walking.Standing.Walk_Forward
local Ragdoll_Status = require(game:GetService("ReplicatedStorage").Shared.Library.Classes.StatusClasses.RagdollStatus)

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
	
	local Equipment_Folder = Instance.new("Folder")
	Equipment_Folder.Name = "Equipment"
	Equipment_Folder.Parent = folder
end

local function fetch_hair_accessories(player: Player)
	local humanoidDescription: HumanoidDescription = Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)

	local accessories = humanoidDescription:GetAccessories(true) -- true includes rigid accessories

	-- // get only hair accessories
	for _, accessory:AccessoriesInfo in pairs(accessories) do
		if not accessory.AccessoryType.Name:find("Hair") then continue end
		print("Asset ID: " .. accessory.AssetId)

		local string_value = Instance.new("StringValue")
		string_value.Parent = player.GameData.Accessorys.Hairs
		string_value.Name = "Hair" .. #player.GameData.Accessorys.Hairs:GetChildren()
		string_value.Value = accessory.AssetId
	end
end


local function setup_player(player: Player)
	setup_gamedata(player)

	local ragdoll_object = Ragdoll_Status.new()
	player.CharacterAdded:Connect(function(character)
		setup_characterdata(character)
		character.Humanoid.BreakJointsOnDeath = false
		character:WaitForChild("Humanoid").Died:Connect(function()
			print("PlayerService: Player died", player.Name)
			character.Archivable = true
			local character_clone = character:Clone()
			
			if workspace.Game_Details:FindFirstChild("Bodies") then
				character_clone.Parent = workspace.Game_Details.Bodies
			else
				local bodies_folder = Instance.new("Folder")
				bodies_folder.Name = "Bodies"
				bodies_folder.Parent = workspace.Game_Details
				character_clone.Parent = bodies_folder
			end
			
			-- // delete original character
			character:Destroy()
			
			ragdoll_object:_special_apply(character_clone)
			print("PlayerService: Player died", player.Name)
			
			player:SetAttribute("Active", nil)
		end)
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
	
	print("Ran playersetup...")
end

return module
