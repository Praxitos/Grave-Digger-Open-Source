local module = {}

local LocalPlayer = game:GetService("Players").LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")

local GunClasses = game:GetService("ReplicatedStorage").Shared.Library.Classes.GunClasses
local ToolClasses = game:GetService("ReplicatedStorage").Shared.Library.Classes.ToolClasses

function module.start_module()
    Backpack.ChildAdded:Connect(function(child)
        if child:IsA("StringValue") then
            local reference = require(GunClasses:FindFirstChild(child.Name)) or require(ToolClasses:FindFirstChild(child.Name))
            if not reference then warn("ToolService: No class found for item", child.Name) return end
        
            reference.new({
                name = child.Name
            }):on_give()
        end
    end)
end

return module