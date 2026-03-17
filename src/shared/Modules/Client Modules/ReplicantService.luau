local module = {}

local player_service = game:GetService("Players")

local function setup_light(parent)
    local light = Instance.new("PointLight")
    light.Parent = parent

    light.Brightness = 0.5
    light.Range = 18
end

local function setup_player(player)
    local Character = player.Character or player.CharacterAdded:Wait()

   setup_light(Character:WaitForChild("Torso")) 

   player.CharacterAdded:Connect(function(char)
        setup_light(char.Torso)
   end)
end


function module.start_module()
    for _, player in pairs(player_service:GetPlayers()) do
        setup_player(player)
    end

    player_service.PlayerAdded:Connect(setup_player)

end

return module