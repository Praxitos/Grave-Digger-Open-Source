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

local current_x_pos = 0
local current_y_pos = 0
local current_z_pos = 0

local blacklists = {
	[Vector3.new(0,0,0)] = true
}

local function flood_map_with_parts()
	local terrain_folder = Instance.new("Folder")
	terrain_folder.Name = "TerrainChunks"
	terrain_folder.Parent = workspace

	local terrain_count = 0

	print(string.format("[TERRAIN] Config loaded — chunk_size: (%d, %d, %d) | limits: x=%d y=%d z=%d | max_chunks: %d",
		chunk_size_x, chunk_size_y, chunk_size_z,
		max_x_limit, max_y_limit, max_z_limit,
		max_chunks
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
	local queue = {Vector3.new(0, 0, 0)}
	local skipped_limit = 0
	local skipped_visited = 0

	while terrain_count < max_chunks and #queue > 0 do
		local pos: Vector3 = table.remove(queue, 1)

		local key = pos.X..","..pos.Y..","..pos.Z
		if visited[key] then
			skipped_visited += 1
			continue
		end

		local cx = math.round(pos.X / chunk_size_x)
		local cy = math.round(pos.Y / chunk_size_y)
		local cz = math.round(pos.Z / chunk_size_z)

		if math.abs(cx) > max_x_limit
			or math.abs(cy) > max_y_limit
			or math.abs(cz) > max_z_limit then
			skipped_limit += 1
			print(string.format("[TERRAIN] REJECTED chunk at world(%.1f, %.1f, %.1f) → coords(%d, %d, %d) | limit hit: x=%s y=%s z=%s",
				pos.X, pos.Y, pos.Z, cx, cy, cz,
				tostring(math.abs(cx) > max_x_limit),
				tostring(math.abs(cy) > max_y_limit),
				tostring(math.abs(cz) > max_z_limit)
				))
			continue
		end

		visited[key] = true

		if math.abs(cx) > math.abs(current_x_pos) then current_x_pos = cx end
		if math.abs(cy) > math.abs(current_y_pos) then current_y_pos = cy end
		if math.abs(cz) > math.abs(current_z_pos) then current_z_pos = cz end

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
	for _, child in ipairs(terrain_chunks_folder:GetChildren()) do
		local pos = child.Position
		local blacklisted = false
		for bl_pos in pairs(blacklists) do
			if bl_pos == pos then
				blacklisted = true
				break
			end
		end

		if not blacklisted then
			terrain:FillBlock(
				child.CFrame,
				child.Size,
				Enum.Material.Rock
			)
		else
			terrain:FillBlock(child.CFrame, child.Size, Enum.Material.Air)
			child.BrickColor = BrickColor.new("Bright red")
		end
	end
end

function module.start_module()
	flood_map_with_parts()
	fill_parts_with_rock()

		delete_terrain.OnServerEvent:Connect(function(player, position, power)

		power = power or "6"
		local terrain_chunks_folder = workspace:WaitForChild("TerrainChunks")
		local chunk_part: Part? = nil

		for _, child in ipairs(terrain_chunks_folder:GetChildren()) do
			if not child:IsA("Part") then continue end

			if (child.Position - position).Magnitude < chunk_size and child.BrickColor ~= BrickColor.new("Bright red")then
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
