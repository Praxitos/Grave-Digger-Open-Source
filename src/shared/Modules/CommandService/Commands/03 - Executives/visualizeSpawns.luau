local locations_folder = game:GetService("ReplicatedStorage").Values.Variables.Spawnings.Locations
local player_service = game:GetService("Players")

local local_player
local mouse

local mousehighlight_gui
local mousehighlight_utils

local connections = {}

local function create_affiliated_spawn(position: Vector3, size: Vector3, name: string)
	if position == Vector3.new(0, 0, 0) then
		return
	end

	local spawns_folder = workspace:FindFirstChild("Spawns")
	if not spawns_folder then
		spawns_folder = Instance.new("Folder")
		spawns_folder.Name = "Spawns"
		spawns_folder.Parent = workspace
	end

	local spawn_part: Part = Instance.new("Part")
	spawn_part.Size = Vector3.new(5 + size.X, 1000 + size.Y, 5 + size.Z)
	spawn_part.Anchored = true
	spawn_part.CanCollide = false
	spawn_part.Transparency = 0.6
	spawn_part.Position = position
	spawn_part.Name = name
	spawn_part.Parent = spawns_folder

	local mouse_detector = Instance.new("ClickDetector")
	mouse_detector.MaxActivationDistance = 1000
	mouse_detector.Parent = spawn_part

	-- Listen for mouse.Target changes
	connections[name] = {
		mouse_detector.MouseHoverEnter:Connect(function()
			mousehighlight_utils.show_highlight(name)
		end),
		
		mouse_detector.MouseHoverLeave:Connect(function()
			mousehighlight_utils.hide_highlight()
		end)
	}
end

local function clean_up()
	local spawns = workspace:FindFirstChild("Spawns")
	if spawns then
		spawns:ClearAllChildren()
	end

	for _, connection in pairs(connections) do
		for _, connectionv2 in pairs(connection) do
			connectionv2:Disconnect()
		end
	end
	connections = {}
end

local function return_offset(name: string)
	local offset_name = name:gsub("_Vector3", "Offset_Vector3")
	local obj = locations_folder:FindFirstChild(offset_name)

	if obj and obj:IsA("Vector3Value") then
		return obj.Value
	end

	return Vector3.new()
end

return {
	Name = "visualizeSpawns";
	Aliases = { "" };
	Description = "Shows both the spawn location and scales size based on the offset vector.";
	Group = "8";

	Args = {
		{
			Type = "boolean";
			Name = "Visibility";
			Description = "True to show spawns, false to hide.";
		},
	};

	ClientRun = function(_, visible: boolean)
		local_player = player_service.LocalPlayer
		mouse = local_player:GetMouse()

		mousehighlight_gui = local_player.PlayerGui:WaitForChild("MouseHighlight")
		mousehighlight_utils = require(mousehighlight_gui.Utils)

		if visible then
			clean_up()

			for _, spawn in pairs(locations_folder:GetChildren()) do
				if not string.find(spawn.Name, "Offset") then
					create_affiliated_spawn(
						spawn.Value,
						return_offset(spawn.Name),
						spawn.Name
					)
				end
			end

			return "Spawn visualization enabled."
		else
			clean_up()
			return "Spawn visualization disabled."
		end
	end,
}
