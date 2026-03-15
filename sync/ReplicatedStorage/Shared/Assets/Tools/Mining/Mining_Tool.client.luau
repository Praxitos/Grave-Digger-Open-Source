local tool:Tool = script.Parent

local delete_terrain: RemoteEvent = game:GetService("ReplicatedStorage").Shared.Library.Events.Terrain_Communication.Delete_Terrain

local function send_raycast(origin, direction)
    local raycast_params = RaycastParams.new()
    raycast_params.FilterType = Enum.RaycastFilterType.Blacklist
    raycast_params.FilterDescendantsInstances = {tool.Parent} -- Ignore the player character

    local raycast_result = workspace:Raycast(origin, direction, raycast_params)
    return raycast_result
end



tool.Activated:Connect(function()
    local raycast = send_raycast(tool.Handle.Position, tool.Handle.CFrame.LookVector * 10)
    print("Raycast result:", raycast)

    if raycast.Instance == game.Workspace.Terrain and raycast.Material == Enum.Material.Rock then
    
        print("Terrain hit at position:", raycast.Position)
        delete_terrain:FireServer(raycast.Position)
    else
        print("No terrain hit.")
    end
end)

print("Mining tool script loaded.")