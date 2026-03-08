-------------
---- // @Praxitos
---- // Stamina Main Handler

-- // Variables

-- Services
local run_service                 = game:GetService("RunService")
local player_service              = game:GetService("Players")
local input_service               = game:GetService("UserInputService")
-- Constants
local local_player                = player_service.LocalPlayer

local player_character            = local_player.Character or local_player.CharacterAdded:Wait()
local character_humanoid          = player_character.Humanoid

-- Variables
local runtime_connections = {}

-- local Config
local added_walkspeed             = 5
local inerita_buildup_time        = 2.5 -- // per frame
local current_buildup_tick        = 0

local sprint_button               = Enum.KeyCode.LeftControl


-- // Functions
local function  cleanup()
    runtime_connections = {}
end


-- begins to buildup the sprint
local function  begin_buildup()
    runtime_connections["buildup"] = run_service.Heartbeat:Connect(function(deltaTime)
        print("buildup")
        if current_buildup_tick * inerita_buildup_time > 5 then return end

        local finalized_walkspeed_value = current_buildup_tick + 1 * inerita_buildup_time

        character_humanoid.WalkSpeed = finalized_walkspeed_value
    end)
end

-- // ends the buildup
local function  end_buildup()
    runtime_connections["builddown"] = run_service.Heartbeat:Connect(function(deltaTime)
        print("Builddown")
        if current_buildup_tick == 0 then cleanup() return end

         local finalized_walkspeed_value = current_buildup_tick - 1 * inerita_buildup_time   
        character_humanoid.WalkSpeed = finalized_walkspeed_value
    end)
end

-- // Connections
input_service.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end

    if input == sprint_button then
        begin_buildup()
    end
end)

input_service.InputEnded:Connect(function(input, gps)
    if gps then return end

    if input == sprint_button then
        end_buildup()
    end

end)

print("[DEBUG::] Stamina_Main Client working!")