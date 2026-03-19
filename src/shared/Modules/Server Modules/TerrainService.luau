--!strict
local module = {}

local terrain = workspace.Terrain
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local delete_terrain: RemoteEvent = ReplicatedStorage.Shared.Library.Events.Terrain_Communication.Delete_Terrain

local terrain_config = ReplicatedStorage.Shared.Library.Configuration.Terrain_Variables
local chunk_limits = terrain_config.Rendering["Chunk Limits"]
local chunk_size = terrain_config.Rendering["Chunk Size"]

-- Config
local max_chunks = chunk_limits.Max_Chunks.Value
local chunk_size_x = chunk_size.Chunk_X.Value
local chunk_size_y = chunk_size.Chunk_Y.Value
local chunk_size_z = chunk_size.Chunk_Z.Value

local max_x_limit = chunk_limits.Max_X_Limit.Value
local max_y_limit = chunk_limits.Max_Y_Limit.Value
local max_z_limit = chunk_limits.Max_Z_Limit.Value

-- Hole config (air gaps cut into the +X and -X edge walls)
local hole_enabled = true       -- toggle holes on/off
local hole_width   = 3          -- how many chunks wide the hole is in Z
local hole_height  = 1          -- how many chunks tall the hole is in Y

local current_x_pos = 0
local current_y_pos = 0
local current_z_pos = 0

local start_position = Vector3.new(0, 0, 0)

local blacklists = {
	[Vector3.new(0, 0, 0)] = true
}

local function flood_map_with_parts()
	local terrain_folder = Instance.new("Folder")
	terrain_folder.Name = "TerrainChunks"
	terrain_folder.Parent = workspace

	local terrain_count = 0

	-- Compute origin in chunk coordinates from start_position
	local origin_cx = math.round(start_position.X / chunk_size_x)
	local origin_cy = math.round(start_position.Y / chunk_size_y)
	local origin_cz = math.round(start_position.Z / chunk_size_z)

	print(string.format("[TERRAIN] Config loaded — chunk_size: (%d, %d, %d) | limits: x=%d y=%d z=%d | max_chunks: %d",
		chunk_size_x, chunk_size_y, chunk_size_z,
		max_x_limit, max_y_limit, max_z_limit,
		max_chunks
		))
	print(string.format("[TERRAIN] Start position: (%.1f, %.1f, %.1f) → origin chunk coords: (%d, %d, %d)",
		start_position.X, start_position.Y, start_position.Z,
		origin_cx, origin_cy, origin_cz
		))

	local function create_part_reference(position)
		local terrain_chunk = Instance.new("Part")
		terrain_chunk.Name = "TerrainChunk" .. terrain_count
		terrain_chunk.Size = Vector3.new(chunk_size_x, chunk_size_y, chunk_size_z)
		terrain_chunk.Position = position
		terrain_chunk.Anchored = true
		terrain_chunk.Transparency = 0.5
		terrain_chunk.Parent = terrain_folder
		terrain_chunk.CanCollide = false

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
		Vector3.new( 0, 0,-1)
	}

	local visited = {}
	local queue = {start_position}
	local skipped_limit = 0
	local skipped_visited = 0

	while terrain_count < max_chunks and #queue > 0 do
		local pos: Vector3 = table.remove(queue, 1)

		local key = pos.X..","..pos.Y..","..pos.Z
		if visited[key] then
			skipped_visited += 1
			continue
		end

		-- Convert world position to chunk coordinates
		local cx = math.round(pos.X / chunk_size_x)
		local cy = math.round(pos.Y / chunk_size_y)
		local cz = math.round(pos.Z / chunk_size_z)

		-- Reject if distance from origin chunk exceeds limits
		if math.abs(cx - origin_cx) > max_x_limit
			or math.abs(cy - origin_cy) > max_y_limit
			or math.abs(cz - origin_cz) > max_z_limit then
			skipped_limit += 1
			print(string.format("[TERRAIN] REJECTED chunk at world(%.1f, %.1f, %.1f) → coords(%d, %d, %d) | limit hit: x=%s y=%s z=%s",
				pos.X, pos.Y, pos.Z, cx, cy, cz,
				tostring(math.abs(cx - origin_cx) > max_x_limit),
				tostring(math.abs(cy - origin_cy) > max_y_limit),
				tostring(math.abs(cz - origin_cz) > max_z_limit)
				))
			continue
		end

		visited[key] = true

		-- Track furthest reach in each axis (relative to origin)
		if math.abs(cx - origin_cx) > math.abs(current_x_pos) then current_x_pos = cx - origin_cx end
		if math.abs(cy - origin_cy) > math.abs(current_y_pos) then current_y_pos = cy - origin_cy end
		if math.abs(cz - origin_cz) > math.abs(current_z_pos) then current_z_pos = cz - origin_cz end

		print(string.format("[TERRAIN] PLACED chunk #%d at world(%.1f, %.1f, %.1f) → coords(%d, %d, %d)",
			terrain_count + 1, pos.X, pos.Y, pos.Z, cx, cy, cz
			))

		create_part_reference(pos)
		terrain_count += 1

		for _, dir in ipairs(directions) do
			local neighbor = pos + dir * chunk_size_x
			table.insert(queue, neighbor)
		end
	end

	print(string.format("[TERRAIN] Done — placed: %d | rejected by limit: %d | skipped visited: %d | furthest coords reached: x=%d y=%d z=%d",
		terrain_count, skipped_limit, skipped_visited,
		current_x_pos, current_y_pos, current_z_pos
		))
end

local function fill_parts_with_rock()
	local terrain_chunks_folder = workspace:WaitForChild("TerrainChunks")

	-- Build a lookup set of all placed chunk positions
	local placed_positions = {}
	for _, child in ipairs(terrain_chunks_folder:GetChildren()) do
		if not child:IsA("Part") then continue end
		local p = child.Position
		placed_positions[p.X..","..p.Y..","..p.Z] = true
	end

	local directions = {
		Vector3.new( 1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new( 0, 1, 0),
		Vector3.new( 0,-1, 0),
		Vector3.new( 0, 0, 1),
		Vector3.new( 0, 0,-1)
	}

	-- Find the extents of the map to center the holes
	local min_cz = math.huge
	local max_cz = -math.huge
	local min_cy = math.huge
	local max_cy = -math.huge
	local max_cx_placed = -math.huge
	local min_cx_placed = math.huge

	for _, child in ipairs(terrain_chunks_folder:GetChildren()) do
		if not child:IsA("Part") then continue end
		local cz = math.round(child.Position.Z / chunk_size_z)
		local cy = math.round(child.Position.Y / chunk_size_y)
		local cx = math.round(child.Position.X / chunk_size_x)
		if cz < min_cz then min_cz = cz end
		if cz > max_cz then max_cz = cz end
		if cy < min_cy then min_cy = cy end
		if cy > max_cy then max_cy = cy end
		if cx > max_cx_placed then max_cx_placed = cx end
		if cx < min_cx_placed then min_cx_placed = cx end
	end

	local center_cz = math.round((min_cz + max_cz) / 2)
	local center_cy = math.round((min_cy + max_cy) / 2)

	-- Derive half-extents from the config vars (floor so odd numbers stay centered)
	local hole_z_half = math.floor(hole_width  / 2)
	local hole_y_half = math.floor(hole_height / 2)

	print(string.format("[TERRAIN] Hole config — enabled: %s | width: %d | height: %d | center Z coord: %d | center Y coord: %d",
		tostring(hole_enabled), hole_width, hole_height, center_cz, center_cy
		))

	local function is_x_edge_hole(cx, cy, cz)
		if not hole_enabled then return false end
		if cx ~= max_cx_placed and cx ~= min_cx_placed then return false end
		if math.abs(cz - center_cz) > hole_z_half then return false end
		if math.abs(cy - center_cy) > hole_y_half then return false end
		return true
	end

	local rock_count = 0
	local basalt_count = 0
	local air_hole_count = 0

	for _, child in ipairs(terrain_chunks_folder:GetChildren()) do
		if not child:IsA("Part") then continue end

		local pos = child.Position
		local cx = math.round(pos.X / chunk_size_x)
		local cy = math.round(pos.Y / chunk_size_y)
		local cz = math.round(pos.Z / chunk_size_z)

		-- Check blacklist
		local blacklisted = false
		for bl_pos in pairs(blacklists) do
			if bl_pos == pos then
				blacklisted = true
				break
			end
		end

		if blacklisted then
			terrain:FillBlock(child.CFrame, child.Size, Enum.Material.Air)
			child.BrickColor = BrickColor.new("Bright red")
			continue
		end

		-- Air hole takes priority over basalt on +X/-X edges
		if is_x_edge_hole(cx, cy, cz) then
			terrain:FillBlock(child.CFrame, child.Size, Enum.Material.Air)
			air_hole_count += 1
			print(string.format("[TERRAIN] HOLE chunk at world(%.1f, %.1f, %.1f) → Air", pos.X, pos.Y, pos.Z))
			continue
		end

		-- A chunk is an edge if any of its 6 neighbours is absent from the placed set
		local is_edge = false
		for _, dir in ipairs(directions) do
			local neighbor = pos + dir * chunk_size_x
			local nkey = neighbor.X..","..neighbor.Y..","..neighbor.Z
			if not placed_positions[nkey] then
				is_edge = true
				break
			end
		end

		if is_edge then
			terrain:FillBlock(child.CFrame, child.Size, Enum.Material.Basalt)
			basalt_count += 1
			print(string.format("[TERRAIN] EDGE chunk at world(%.1f, %.1f, %.1f) → Basalt", pos.X, pos.Y, pos.Z))
		else
			terrain:FillBlock(child.CFrame, child.Size, Enum.Material.Rock)
			rock_count += 1
		end
	end

	print(string.format("[TERRAIN] Fill done — Rock: %d | Basalt (edge): %d | Air holes: %d", rock_count, basalt_count, air_hole_count))
end

function module.start_module()
	if workspace:FindFirstChild("Terrain_Start") then
		start_position = workspace:FindFirstChild("Terrain_Start").Position
	end

	if max_chunks == 0 then max_chunks = math.huge end

	flood_map_with_parts()
	fill_parts_with_rock()

	delete_terrain.OnServerEvent:Connect(function(player, position, power)

		power = power or "6"
		local terrain_chunks_folder = workspace:WaitForChild("TerrainChunks")
		local chunk_part: Part? = nil

		for _, child in ipairs(terrain_chunks_folder:GetChildren()) do
			if not child:IsA("Part") then continue end

			if (child.Position - position).Magnitude < chunk_size_x and child.BrickColor ~= BrickColor.new("Bright red") then
				chunk_part = child
				break
			else
				continue
			end
		end

		if not chunk_part then
			warn("[TERRAIN_SERVICE:: No chunk found for edit]")
			return
		end

		local edits_folder = chunk_part:FindFirstChild("Edits")

		if not edits_folder then
			edits_folder = Instance.new("Folder")
			edits_folder.Name = "Edits"
			edits_folder.Parent = chunk_part
		end

		local string_value = Instance.new("StringValue")
		string_value.Name = "Edit_" .. time()
		string_value.Value = string.format("%f,%f,%f, %f", position.X, position.Y, position.Z, power)
		string_value.Parent = edits_folder

	end)
end

return module