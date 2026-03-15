local tool:Tool = script.Parent

local delete_terrain: RemoteEvent = game:GetService("ReplicatedStorage").Shared.Library.Events.Terrain_Communication.Delete_Terrain
local Workspace = game:GetService("Workspace")

local function send_raycast(origin, direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = {workspace.Terrain}

	return workspace:Raycast(origin, direction, params)
end



tool.Activated:Connect(function()
	print("Tool activated!")
    local raycast = send_raycast(Workspace.CurrentCamera.CFrame.Position, Workspace.CurrentCamera.CFrame.LookVector * 13)
    print("Raycast result:", raycast)

    if raycast.Instance == nil then return end

    if raycast.Instance and raycast.Instance == game.Workspace.Terrain and raycast.Material == Enum.Material.Rock then
    
        print("Terrain hit at position:", raycast.Position)
        delete_terrain:FireServer(raycast.Position)
    else
        print("No terrain hit.")
    end
end)

print("Client script loaded for", tool.Name)