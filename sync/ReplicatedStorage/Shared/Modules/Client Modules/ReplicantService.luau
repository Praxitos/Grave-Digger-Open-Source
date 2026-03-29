local module = {}

local player_service = game:GetService("Players")
local tool_holsters_reference_folder = game.ReplicatedStorage.Shared.Assets.Guns.Holsters["Tool Holsters"]
local gun_holsters_reference_folder = game.ReplicatedStorage.Shared.Assets.Guns.Holsters["Gun Holsters"]
local utilities_module = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("Util"))

local function setup_light(parent)
    local light = Instance.new("PointLight")
    light.Parent = parent

    light.Brightness = 0.5
    light.Range = 18
end

local function generate_hair(player, accessorys_folder:Folder)
    for _, child in pairs(accessorys_folder:GetChildren()) do
        --- TODO: Generate Hair Accessories to the player    
    end

end

local function setup_player(player)
    local Character = player.Character or player.CharacterAdded:Wait()
    local gameData_Folder = player:WaitForChild("GameData")
    local accessorys_folder = gameData_Folder:WaitForChild("Accessorys")
    local holsters_folder = accessorys_folder:WaitForChild("Holsters")
    


   setup_light(Character:WaitForChild("Torso")) 

    if player.Character then
        generate_hair(player, accessorys_folder)
    end

   player.CharacterAdded:Connect(function(char)
        generate_hair(player, accessorys_folder)
        setup_light(char.Torso)
   end)

   holsters_folder.ChildAdded:Connect(function(child: BoolValue)
        print("Detected child added for:", child.Name)
		if not tool_holsters_reference_folder:FindFirstChild(child.Name) and not gun_holsters_reference_folder:FindFirstChild(child.Name) then warn("Received holster child for:", child.Name, "but not reference found...") end

        print("Child added, does have reference...")

		local reference = tool_holsters_reference_folder:FindFirstChild(child.Name) or gun_holsters_reference_folder:FindFirstChild(child.Name)
        	local primary_part = reference.PrimaryPart
		if not primary_part then
			warn("ToolService: No primary part found for holster", child.Name)
			return
		end

		local body_part_name = string.split(primary_part.Name, "_")[2]
		local character = player.Character

		if not character or not character:FindFirstChild(body_part_name) then
			warn("ToolService: No corresponding body part found for holster", child.Name)
			return
		end

		local clone = reference:Clone()

		utilities_module.quick_weld(
			clone.PrimaryPart,
			character[body_part_name],
			clone,
			child.Name .. "_Weld"
		)

		clone.Parent = character.CharacterData.Rendered_Holsters
		
		child:GetPropertyChangedSignal("Value"):Connect(function()
			for _, childv2 in pairs(clone:GetChildren()) do
				if not childv2:GetAttribute("Hide_On_Equip") then continue end
				
				if child.Value == true then childv2.Transparency = 0 else childv2.Transparency = 1 end
			end
		end)
   end)
   
   holsters_folder.ChildRemoved:Connect(function(child)
		print("Detected child removed")
		
		local reference = tool_holsters_reference_folder:FindFirstChild(child.Name) or gun_holsters_reference_folder:FindFirstChild(child.Name)
		reference:Destroy()
   end)
end


function module.start_module()
    for _, player in pairs(player_service:GetPlayers()) do
        setup_player(player)
    end

    player_service.PlayerAdded:Connect(setup_player)

end

return module