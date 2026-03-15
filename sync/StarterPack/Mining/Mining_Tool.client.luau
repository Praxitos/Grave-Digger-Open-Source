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
    local raycast = send_raycast(Workspace.CurrentCamera.CFrame.Position, Workspace.CurrentCamera.CFrame.LookVector * 13)

    if raycast == nil then return end

    if raycast.Instance and raycast.Instance == game.Workspace.Terrain and raycast.Material == Enum.Material.Rock then
        delete_terrain:FireServer(raycast.Position)
    end
end)