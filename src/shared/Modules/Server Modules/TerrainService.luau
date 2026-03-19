--!strict
local module = {}

local terrain = workspace.Terrain
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local delete_terrain: RemoteEvent = ReplicatedStorage.Shared.Library.Events.Terrain_Communication.Delete_Terrain

local terrain_config = ReplicatedStorage.Shared.Library.Configuration.Terrain_Variables
local chunk_limits = terrain_config.Rendering["Chunk Limits"]
local chunk_size = terrain_config.Rendering["Chunk Size"]

local spawn_rooms = ReplicatedStorage.Shared.Assets.SpawnRooms
local nation_spawn_room = spawn_rooms.Regular.Nation
local empire_spawn_room = spawn_rooms.Regular.Empire

-- Config
local max_chunks = chunk_limits.Max_Chunks.Value
local chunk_size_x = chunk_size.Chunk_X.Value
local chunk_size_y = chunk_size.Chunk_Y.Value
local chunk_size_z = chunk_size.Chunk_Z.Value

local max_x_limit = chunk_limits.Max_X_Limit.Value
local max_y_limit = chunk_limits.Max_Y_Limit.Value
local max_z_limit = chunk_limits.Max_Z_Limit.Value

-- // connects/entrances
local tunnel_width  = chunk_size_x * 0.8
local tunnel_height = chunk_size_y * 0.6
local tunnel_length = chunk_size_x * 1.5
local vertical_offset = -(chunk_size_y * -0.3)

-- Spawn room config
local room_depth_chunks = 3

local current_x_pos = 0
local current_y_pos = 0
local current_z_pos = 0

local start_position = Vector3.new(0, 0, 0)

local blacklists = {
	[Vector3.new(0, 0, 0)] = true
}

--------------------------------------------------
-- FLOOD (UNCHANGED)
--------------------------------------------------

local function flood_map_with_parts()
	local terrain_folder = Instance.new("Folder")
	terrain_folder.Name = "TerrainChunks"
	terrain_folder.Parent = workspace

	local terrain_count = 0

	local origin_cx = math.round(start_position.X / chunk_size_x)
	local origin_cy = math.round(start_position.Y / chunk_size_y)
	local origin_cz = math.round(start_position.Z / chunk_size_z)

	local function create_part_reference(position)
		local terrain_chunk = Instance.new("Part")
		terrain_chunk.Name = "TerrainChunk" .. terrain_count
		terrain_chunk.Size = Vector3.new(chunk_size_x, chunk_size_y, chunk_size_z)
		terrain_chunk.Position = position
		terrain_chunk.Anchored = true
		terrain_chunk.Transparency = 1
		terrain_chunk.Parent = terrain_folder
		terrain_chunk.CanCollide = false

		local edits_folder = Instance.new("Folder")
		edits_folder.Name = "Edits"
		edits_folder.Parent = terrain_chunk
	end

	local directions = {
		Vector3.new( 1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new( 0, 1, 0),
		Vector3.new( 0,-1, 0),
		Vector3.new( 0, 0, 1),
		Vector3.new( 0, 0,-1)
	}

	local visited = {}
	local queue = {start_position}

	while terrain_count < max_chunks and #queue > 0 do
		local pos: Vector3 = table.remove(queue, 1)

		local key = pos.X..","..pos.Y..","..pos.Z
		if visited[key] then continue end

		local cx = math.round(pos.X / chunk_size_x)
		local cy = math.round(pos.Y / chunk_size_y)
		local cz = math.round(pos.Z / chunk_size_z)

		if math.abs(cx - origin_cx) > max_x_limit
			or math.abs(cy - origin_cy) > max_y_limit
			or math.abs(cz - origin_cz) > max_z_limit then
			continue
		end

		visited[key] = true
		create_part_reference(pos)
		terrain_count += 1

		for _, dir in ipairs(directions) do
			table.insert(queue, pos + dir * chunk_size_x)
		end
	end
end

--------------------------------------------------
--  FIXED SPAWN ROOMS
--------------------------------------------------

local function place_spawn_rooms(max_cx_placed, min_cx_placed, center_cz, center_cy)

	local function carve_block(cf: CFrame, size: Vector3)
		terrain:FillBlock(cf, size, Enum.Material.Air)
	end

	local function place_room(room_template, wall_cx: number, facing_dir: number)
		local room: Model = room_template:Clone()
		room.Parent = workspace

		local primary = room.PrimaryPart
		if not primary then return end

		local wall_outer_x = wall_cx * chunk_size_x
		local room_center_x = wall_outer_x + (-facing_dir * chunk_size_x * room_depth_chunks)

		local room_center_y = (center_cy * chunk_size_y)
		local room_center_z = (center_cz * chunk_size_z)

		local room_center = Vector3.new(room_center_x, room_center_y, room_center_z)

		room:PivotTo(CFrame.new(room_center) * CFrame.Angles(math.rad(90), 0, 0))

		local actual_x = primary.Position.X
		local actual_y = primary.Position.Y
		local actual_z = primary.Position.Z

		local psx = primary.Size.X
		local psy = primary.Size.Y
		local psz = primary.Size.Z

		--  Vertical fix
		local entrance_y = actual_y + vertical_offset

		--  BASALT SHELL
		local shell_size = Vector3.new(psx + 10, psy + 10, psz + 10)
		terrain:FillBlock(primary.CFrame, shell_size, Enum.Material.Basalt)

		-- Hollow interior
		local air_part = room:FindFirstChild("Air", true)
		if air_part then
			terrain:FillBlock(air_part.CFrame, air_part.Size, Enum.Material.Air)
		end

		--------------------------------------------------
		--  CROSS ENTRANCES (FIXED)
		--------------------------------------------------

		-- X axis tunnels
		carve_block(
			CFrame.new(actual_x + (facing_dir * (psx/2)), entrance_y, actual_z),
			Vector3.new(tunnel_length, tunnel_height, tunnel_width)
		)

		carve_block(
			CFrame.new(actual_x - (facing_dir * (psx/2)), entrance_y, actual_z),
			Vector3.new(tunnel_length, tunnel_height, tunnel_width)
		)

		-- Z axis tunnels
		carve_block(
			CFrame.new(actual_x, entrance_y, actual_z + (psy/2)),
			Vector3.new(tunnel_width, tunnel_height, tunnel_length)
		)

		carve_block(
			CFrame.new(actual_x, entrance_y, actual_z - (psy/2)),
			Vector3.new(tunnel_width, tunnel_height, tunnel_length)
		)

		print("[TERRAIN] Spawn room placed with CROSS tunnels")
	end

	place_room(nation_spawn_room, max_cx_placed,  1)
	place_room(empire_spawn_room, min_cx_placed, -1)
end

--------------------------------------------------
-- FILL (UNCHANGED EXCEPT CALL)
--------------------------------------------------

local function fill_parts_with_rock()
	local terrain_chunks_folder = workspace:WaitForChild("TerrainChunks")

	local min_cz, max_cz = math.huge, -math.huge
	local min_cy, max_cy = math.huge, -math.huge
	local max_cx_placed, min_cx_placed = -math.huge, math.huge

	for _, child in ipairs(terrain_chunks_folder:GetChildren()) do
		if not child:IsA("Part") then continue end

		local cx = math.round(child.Position.X / chunk_size_x)
		local cy = math.round(child.Position.Y / chunk_size_y)
		local cz = math.round(child.Position.Z / chunk_size_z)

		min_cz = math.min(min_cz, cz)
		max_cz = math.max(max_cz, cz)
		min_cy = math.min(min_cy, cy)
		max_cy = math.max(max_cy, cy)
		max_cx_placed = math.max(max_cx_placed, cx)
		min_cx_placed = math.min(min_cx_placed, cx)

		terrain:FillBlock(child.CFrame, child.Size, Enum.Material.Rock)
	end

	local center_cz = math.round((min_cz + max_cz) / 2)
	local center_cy = math.round((min_cy + max_cy) / 2)

	place_spawn_rooms(max_cx_placed, min_cx_placed, center_cz, center_cy)
end

--------------------------------------------------
-- START
--------------------------------------------------

function module.start_module()
	if workspace:FindFirstChild("Terrain_Start") then
		start_position = workspace.Terrain_Start.Position
	end

	if max_chunks == 0 then
		max_chunks = math.huge
	end

	flood_map_with_parts()
	fill_parts_with_rock()
end

return module