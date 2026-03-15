------------------
-- // Praxitos
-- // Primary Client Setup Handler
------------------

-- // Variable References
local replicatedstorage_service     = game:GetService("ReplicatedStorage")
local modules_folder                = replicatedstorage_service.Shared.Modules

-- // Functions
-- Starts all the Modules
local function start_modules()
    for _, child in pairs(modules_folder["Client Modules"]:GetChildren()) do
        local required_child = require(child)
        if required_child.start_module then
            required_child.start_module()
        end
    end
end

-- Disable Base Roblox Setups
local function disable_base_setups()
    
    -- // disables autorotate
    game.Players.LocalPlayer.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.AutoRotate = false
    end)
end

-- // Init
start_modules()
disable_base_setups()