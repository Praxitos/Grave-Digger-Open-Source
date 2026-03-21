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
local max_chunks_raw = chunk_limits.Max_Chunks.Value
local chunk_size_x = chunk_size.Chunk_X.Value
local chunk_size_y = chunk_size.Chunk_Y.Value
local chunk_size_z = chunk_size.Chunk_Z.Value

local max_x_limit = chunk_limits.Max_X_Limit.Value
local max_y_limit = chunk_limits.Max_Y_Limit.Value
local max_z_limit = chunk_limits.Max_Z_Limit.Value

-- Tunnel config
local tunnel_width  = chunk_size_x * 0.8
local tunnel_height = chunk_size_y * 0.6
local tunnel_length = chunk_size_x * 1.5

-- Spawn room config
local room_depth_chunks = 3

local start_position = Vector3.new(0, 0, 0)

-- max_chunks: if 0, use a large safe number (math.huge breaks IntValue)
local max_chunks = (max_chunks_raw == 0) and 999999 or max_chunks_raw

--------------------------------------------------
-- LOGGING HELPER (delete only)
--------------------------------------------------

local function log(tag: string, msg: string, ...)
	print(string.format("[TERRAIN][%s] " .. msg, tag, ...))
end

local function warn_log(tag: string, msg: string, ...)
	warn(string.format("[TERRAIN][%s] " .. msg, tag, ...))
end

--------------------------------------------------
-- FLOOD
--------------------------------------------------

local function flood_map_with_parts(): {Part}
	local terrain_folder = Instance.new("Folder")
	terrain_folder.Name = "TerrainChunks"
	terrain_folder.Parent = workspace

	local terrain_count = 0
	local chunk_parts: {Part} = {}

	local origin_cx = math.round(start_position.X / chunk_size_x)
	local origin_cy = math.round(start_position.Y / chunk_size_y)
	local origin_cz = math.round(start_position.Z / chunk_size_z)

	local function create_part_reference(position: Vector3): Part
		local terrain_chunk = Instance.new("Part")
		terrain_chunk.Name = "TerrainChunk" .. terrain_count
		terrain_chunk.Size = Vector3.new(chunk_size_x, chunk_size_y, chunk_size_z)
		terrain_chunk.Position = position
		terrain_chunk.Anchored = true
		terrain_chunk.Transparency = 1
		terrain_chunk.CanCollide = false
		terrain_chunk.CanQuery = false
		terrain_chunk.Parent = terrain_folder

		local edits_folder = Instance.new("Folder")
		edits_folder.Name = "Edits"
		edits_folder.Parent = terrain_chunk

		return terrain_chunk
	end

	local directions = {
		Vector3.new( 1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new( 0, 1, 0),
		Vector3.new( 0,-1, 0),
		Vector3.new( 0, 0, 1),
		Vector3.new( 0, 0,-1),
	}

	local visited = {}
	local queue = {start_position}

	while terrain_count < max_chunks and #queue > 0 do
		local pos: Vector3 = table.remove(queue, 1)

		local key = pos.X .. "," .. pos.Y .. "," .. pos.Z
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
		local part = create_part_reference(pos)
		table.insert(chunk_parts, part)
		terrain_count += 1

		for _, dir in ipairs(directions) do
			table.insert(queue, pos + Vector3.new(
				dir.X * chunk_size_x,
				dir.Y * chunk_size_y,
				dir.Z * chunk_size_z
				))
		end
	end

	return chunk_parts
end

--------------------------------------------------
-- SPAWN ROOMS
--------------------------------------------------

local function place_spawn_rooms(
	max_world_x: number,
	min_world_x: number,
	center_world_y: number,
	center_world_z: number
)
	if max_world_x == -math.huge or min_world_x == math.huge
		or max_world_x ~= max_world_x or min_world_x ~= min_world_x then
		return
	end

	local function carve_block(cf: CFrame, size: Vector3)
		local safe_size = Vector3.new(math.max(size.X, 1), math.max(size.Y, 1), math.max(size.Z, 1))
		terrain:FillBlock(cf, safe_size, Enum.Material.Air)
	end

	local function place_room(room_template: Model, edge_world_x: number, facing_dir: number)
		local room: Model = room_template:Clone()
		room.Name = room_template.Name .. "_Placed"
		room.Parent = workspace

		local primary = room.PrimaryPart
		if not primary then
			room:Destroy()
			return
		end

		local room_center = Vector3.new(
			edge_world_x - (facing_dir * chunk_size_x * room_depth_chunks),
			center_world_y,
			center_world_z
		)

		room:PivotTo(CFrame.new(room_center) * CFrame.Angles(math.rad(90), 0, 0))

		local ppos  = primary.Position
		local pcf   = primary.CFrame
		local psize = primary.Size

		local shell_size = Vector3.new(
			math.max(psize.X + 10, 1),
			math.max(psize.Y + 10, 1),
			math.max(psize.Z + 10, 1)
		)
		terrain:FillBlock(pcf, shell_size, Enum.Material.Basalt)

		local air_part = room:FindFirstChild("Air", true)
		if air_part and air_part:IsA("BasePart") then
			local asize = air_part.Size
			terrain:FillBlock(air_part.CFrame, Vector3.new(math.max(asize.X,1), math.max(asize.Y,1), math.max(asize.Z,1)), Enum.Material.Air)
		else
			terrain:FillBlock(pcf, Vector3.new(math.max(psize.X-4,1), math.max(psize.Y-4,1), math.max(psize.Z-4,1)), Enum.Material.Air)
		end

		local shell_half_x = (psize.X + 10) / 2
		local shell_half_z = (psize.Z + 10) / 2
		local world_center_y = ppos.Y

		-- FRONT door + rock tunnel
		carve_block(CFrame.new(ppos.X - (facing_dir * shell_half_x), world_center_y + 2, ppos.Z), Vector3.new(20, tunnel_height, tunnel_width))
		carve_block(CFrame.new(ppos.X - (facing_dir * (shell_half_x + tunnel_length)), world_center_y + 2, ppos.Z), Vector3.new(tunnel_length * 2, tunnel_height, tunnel_width))

		-- BACK door + rock tunnel
		carve_block(CFrame.new(ppos.X + (facing_dir * shell_half_x), world_center_y + 2, ppos.Z), Vector3.new(20, tunnel_height, tunnel_width))
		carve_block(CFrame.new(ppos.X + (facing_dir * (shell_half_x + tunnel_length)), world_center_y + 2, ppos.Z), Vector3.new(tunnel_length * 2, tunnel_height, tunnel_width))

		-- LEFT door + rock tunnel
		carve_block(CFrame.new(ppos.X, world_center_y + 2, ppos.Z - shell_half_z), Vector3.new(tunnel_width, tunnel_height, 20))
		carve_block(CFrame.new(ppos.X, world_center_y + 2, ppos.Z - (shell_half_z + tunnel_length)), Vector3.new(tunnel_width, tunnel_height, tunnel_length * 2))

		-- RIGHT door + rock tunnel
		carve_block(CFrame.new(ppos.X, world_center_y + 2, ppos.Z + shell_half_z), Vector3.new(tunnel_width, tunnel_height, 20))
		carve_block(CFrame.new(ppos.X, world_center_y + 2, ppos.Z + (shell_half_z + tunnel_length)), Vector3.new(tunnel_width, tunnel_height, tunnel_length * 2))
	end

	place_room(nation_spawn_room, max_world_x,  1)
	place_room(empire_spawn_room, min_world_x, -1)
end

--------------------------------------------------
-- FILL
--------------------------------------------------

local function fill_parts_with_rock(chunk_parts: {Part})
	if #chunk_parts == 0 then return end

	local min_world_z, max_world_z = math.huge, -math.huge
	local min_world_y, max_world_y = math.huge, -math.huge
	local max_world_x, min_world_x = -math.huge, math.huge

	for _, child in ipairs(chunk_parts) do
		local pos = child.Position

		min_world_z = math.min(min_world_z, pos.Z)
		max_world_z = math.max(max_world_z, pos.Z)
		min_world_y = math.min(min_world_y, pos.Y)
		max_world_y = math.max(max_world_y, pos.Y)
		max_world_x = math.max(max_world_x, pos.X)
		min_world_x = math.min(min_world_x, pos.X)

		terrain:FillBlock(child.CFrame, child.Size, Enum.Material.Rock)
	end

	task.wait()

	place_spawn_rooms(max_world_x, min_world_x, (min_world_y + max_world_y) / 2, (min_world_z + max_world_z) / 2)
end

--------------------------------------------------
-- START
--------------------------------------------------

function module.start_module()
	if workspace:FindFirstChild("Terrain_Start") then
		start_position = workspace.Terrain_Start.Position
	end

	if max_chunks_raw == 0 then
		max_chunks = 999999
	end

	local chunk_parts = flood_map_with_parts()
	fill_parts_with_rock(chunk_parts)

	-- Build registry for fast delete lookups
	local chunk_registry: {{part: Part, position: Vector3}} = {}
	for _, part in ipairs(chunk_parts) do
		table.insert(chunk_registry, { part = part, position = part.Position })
	end

	delete_terrain.OnServerEvent:Connect(function(player, position, radius)
		log("DELETE", "Received from '%s'  pos=%s  radius=%.2f", player.Name, tostring(position), radius)

		if typeof(position) ~= "Vector3" then
			warn_log("DELETE", "Invalid position from '%s' — expected Vector3, got %s", player.Name, typeof(position))
			return
		end

		if type(radius) ~= "number" or radius <= 0 then
			warn_log("DELETE", "Invalid radius from '%s' — got %s", player.Name, tostring(radius))
			return
		end

		local nearest_part: Part? = nil
		local nearest_dist = math.huge

		for _, entry in ipairs(chunk_registry) do
			local dist = (entry.position - position).Magnitude
			if dist < nearest_dist then
				nearest_dist = dist
				nearest_part = entry.part
			end
		end

		log("DELETE", "Nearest chunk search: closest=%.2f studs", nearest_dist)

		if nearest_part == nil or nearest_dist > chunk_size_x then
			warn_log("DELETE", "No TerrainChunk near %s (closest=%.2f studs, threshold=%.2f)", tostring(position), nearest_dist, chunk_size_x / 2)
			warn_log("DELETE", "Registry size: %d  |  Nearest part: %s", #chunk_registry, nearest_part and tostring(nearest_part.Position) or "nil")
			return
		end

		log("DELETE", "Nearest chunk: '%s' at %s  dist=%.2f", nearest_part.Name, tostring(nearest_part.Position), nearest_dist)

		local edits_folder = nearest_part:FindFirstChild("Edits")
		if not edits_folder then
			warn_log("DELETE", "Chunk '%s' has no Edits folder — creating one", nearest_part.Name)
			edits_folder = Instance.new("Folder")
			edits_folder.Name = "Edits"
			edits_folder.Parent = nearest_part
		end

		local edit_entry = Instance.new("StringValue")
		edit_entry.Name = "Edit_" .. (#edits_folder:GetChildren() + 1)
		edit_entry.Value = string.format("%.4f,%.4f,%.4f,%.4f", position.X, position.Y, position.Z, radius)
		edit_entry.Parent = edits_folder

		log("DELETE", "Recorded edit '%s' = '%s'", edit_entry.Name, edit_entry.Value)

		terrain:FillBall(position, radius, Enum.Material.Air)

		log("DELETE", "FillBall Air complete  pos=%s  radius=%.2f", tostring(position), radius)
	end)
end

return module