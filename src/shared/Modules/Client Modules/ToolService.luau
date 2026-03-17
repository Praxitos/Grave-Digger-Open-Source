local module = {}

local LocalPlayer = game:GetService("Players").LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local GameData = LocalPlayer:WaitForChild("GameData")
local Accessory_Folder = GameData:WaitForChild("Accessorys")
local Holster_Folder = Accessory_Folder:WaitForChild("Holsters")
local ToolHolster_Folder = game:GetService("ReplicatedStorage").Shared.Assets.Holsters:FindFirstChild("Tool Holsters");

local GunClasses = game:GetService("ReplicatedStorage").Shared.Library.Classes.GunClasses
local ToolClasses = game:GetService("ReplicatedStorage").Shared.Library.Classes.ToolClasses

local Util_Module = require(script.Parent.Parent.Parent.Library.Util)

module.RegisteredTools = {}

function module.start_module()
    Backpack.ChildAdded:Connect(function(child)
    if module.RegisteredTools[child.Name] then return end    
    if not child:IsA("Tool") then return end

    local moduleScript =
        GunClasses:FindFirstChild(child.Name, true)
        or ToolClasses:FindFirstChild(child.Name, true)

    if not moduleScript then
        warn("ToolService: No class found for item", child.Name)
        return
    end


    local class = require(moduleScript)

    local instance = class.new({
        name = child.Name
    })

    instance:on_give(child)
    print("ToolService: Called on_give for", child.Name)
    module.RegisteredTools[child.Name] = instance
    end)

    Backpack.ChildRemoved:Connect(function(child)
        if not module.RegisteredTools[child.Name] then return end
        if not child:IsA("Tool") then return end
        if LocalPlayer.Character:FindFirstChild(child.Name) then return end

        module.RegisteredTools[child.Name] = nil
    end)
    Holster_Folder.ChildAdded:Connect(function(child)
        if ToolHolster_Folder:FindFirstChild(child.Name) then
            local Reference: Model = ToolHolster_Folder:FindFirstChild(child.Name)
            local primary_part = Reference.PrimaryPart
            if not primary_part then warn("ToolService: No primary part found for holster", child.Name) return end

            if not LocalPlayer.Character:FindFirstChild(string.split(primary_part.Name, "_")[2]) then
                warn("ToolService: No corresponding body part found for holster", child.Name)
                return
            end

            local clone = Reference:Clone()
            Util_Module.quick_weld(clone.PrimaryPart, LocalPlayer.Character[string.split(primary_part.Name, "_")[2]], clone, child.Name .. "_Weld")
            clone.Parent = LocalPlayer.Character.CharacterData.Rendered_Holsters
        else
            warn("ToolService: No holster reference found for item", child.Name)
        end
    end)
end

return module
