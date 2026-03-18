local module = {}

local types_module = require(game:GetService("ReplicatedStorage").Shared.Library.Types)
local type_checker_module = require(game:GetService("ReplicatedStorage").Shared.Library.Externals.TypeChecker)

local item_classes = game:GetService("ReplicatedStorage").Shared.Library.Classes.ToolClasses



function module.give_item(player: Player, item: string)
    print("Received with:", player.Name, item)
    local item_module = item_classes:FindFirstChild(item)
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

        local string_value = Instance.new("StringValue")
        string_value.Name = object.holster_reference.Name
        string_value.Parent = player.GameData.Accessorys.Holsters
    else
        print("No Holster.", object)
    end

    return "Successfully gave item."
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