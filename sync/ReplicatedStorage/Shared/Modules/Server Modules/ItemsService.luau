local module = {}

local types_module = require(game:GetService("ReplicatedStorage").Shared.Library.Types)
local type_checker_module = require(game:GetService("ReplicatedStorage").Shared.Library.Externals.TypeChecker)

local item_classes = game:GetService("ReplicatedStorage").Shared.Library.Classes.ToolClasses
local gun_classes = game:GetService("ReplicatedStorage").Shared.Library.Classes.GunClasses


function module.give_item(player: Player, item: string)
    print("Received with:", player.Name, item)
    local item_module = item_classes:FindFirstChild(item) or gun_classes:FindFirstChild(item)
    if not item_module then
        warn("ItemsService: Item class not found:", item)
        return "ItemService: Item Class not found.", item
    end

    -- require class
    local class = require(item_module)

    -- create instance of the class
    local object = class.new({
        name = item
    })

    -- create roblox tool
    local tool = Instance.new("Tool")
    tool.Name = object.name
    tool.Parent = player:WaitForChild("Backpack")

    tool.RequiresHandle = false
    print("ItemsService: Gave item", item, "to", player.Name)

    -- check instance property (not class property)
    if object.holster_reference then
        print("Has Holster", object)

        local string_value = Instance.new("BoolValue")
        string_value.Name = object.holster_reference.Name
		string_value.Parent = player.GameData.Accessorys.Holsters
		string_value.Value = true		
				
		tool.Equipped:Connect(function()
			string_value.Value = false

			if object.model_reference then
				local clone = object.model_reference:Clone()
				clone.Parent = player.Character.CharacterData.Equipment
				object.actual_model = clone

				print("Cloned ModelReference")

				local character = player.Character

				-- Resolve Part0 safely (supports fallback)
				local part0 = character:FindFirstChild(object.motor_6d_data.Part0)
					or character:FindFirstChild(object.motor_6d_data.Parent)

				if not part0 then
					warn("Could not find Part0:", object.motor_6d_data.Part0)
					return
				end

				-- Resolve Part1 from cloned model
				local part1 = clone:FindFirstChild(object.motor_6d_data.Part1.Name, true)

				if not part1 then
					warn("Could not find Part1 in model:", object.motor_6d_data.Part1)
					return
				end

				local motor6d: Motor6D = Instance.new("Motor6D")
				motor6d.Name = "ToolMotor"
				motor6d.Parent = part0

				motor6d.Part0 = part0
				motor6d.Part1 = part1
				motor6d.C0 = object.motor_6d_data.C0

				print("Created Motor6D:", part0.Name, "->", part1.Name)
			end
			
			-- // has a round it wants to be weld too
			if object.Round then
				local object_bullet_clone = object.Round:Clone()
				object_bullet_clone.Parent = player.Character["Right Arm"]
				
				local motor6d = Instance.new("Motor6D")
				motor6d.Parent = player.Character["Right Arm"]
				motor6d.Part0 = player.Character["Right Arm"]
				motor6d.Part1 = object_bullet_clone
				
				motor6d.C1 = CFrame.new(0,-0.78,0)
				
				print("Succesfully gave round")
			end
		end)
		
		tool.Unequipped:Connect(function()
			string_value.Value = true
			
			player.Character.CharacterData.Equipment:FindFirstChild(object.model_reference.Name):Destroy()
		end)
    else
        print("No Holster.", object)
	end
	
	if object.model_reference then
		print("Has model reference")
	end

    return "Successfully gave item."
end

function module.remove_item(player: Player, item: string)
    print("Removing item:", player.Name, item)

    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character

    local removed = false

    --  Remove from Backpack
    if backpack then
        local tool = backpack:FindFirstChild(item)
        if tool then
            tool:Destroy()
            removed = true
        end
    end

    --  Remove if currently equipped
    if character then
        local tool = character:FindFirstChild(item)
        if tool then
            tool:Destroy()
            removed = true
        end
    end

    -- Remove holster reference
    local holsters_folder = player:FindFirstChild("GameData")
        and player.GameData:FindFirstChild("Accessorys")
        and player.GameData.Accessorys:FindFirstChild("Holsters")

    if holsters_folder then
        local holster_value = holsters_folder:FindFirstChild(item .. "Holster")
        if holster_value then
            holster_value:Destroy()
        end
    end

    if removed then
        print("ItemsService: Removed item", item, "from", player.Name)
        return "Successfully removed item."
    else
        warn("ItemsService: Item not found:", item)
        return "Item not found."
    end
end

function module.start_module()
    -- validate item class modules
    for _, child in ipairs(item_classes:GetChildren()) do

        local class = require(child)

        if type_checker_module.new(types_module.BaseToolClass, class) then
            print("ItemsService: Checked item class", child.Name)
        else
            warn("ItemsService: Item class", child.Name, "is missing required fields!")
            child:Destroy()
        end

    end
end


return module