local module = {}

-- // services
local terrain_service = workspace.Terrain

-- // variables
local terrain_count = 0

-- blacklisted positions (no rock)
local blacklists = {
	[Vector3.new(0,0,0)] = true
}

-- // flood map with terrain chunks
local function flood_map_with_parts()
	local terrain_folder = Instance.new("Folder")
	terrain_folder.Name = "TerrainChunks"
	terrain_folder.Parent = workspace

	local terrain_count = 0
	local max_chunks = 200
	local chunk_size = 32
	local max_dimension = 320

	-- function to create a part reference
	local function create_part_reference(position)
		local terrain_chunk = Instance.new("Part")
		terrain_chunk.Name = "TerrainChunk" .. terrain_count
		terrain_chunk.Size = Vector3.new(chunk_size, chunk_size, chunk_size)
		terrain_chunk.Position = position
		terrain_chunk.Anchored = true
		terrain_chunk.Transparency = 0.5
		terrain_chunk.Parent = terrain_folder
		terrain_chunk.CanCollide = false
		return terrain_chunk
	end

	-- queue-based expansion for volumetric spread
	local directions = {
		Vector3.new( 1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new( 0, 1, 0),
		Vector3.new( 0,-1, 0),
		Vector3.new( 0, 0, 1),
		Vector3.new( 0, 0,-1)
	}

	local visited = {}
	local queue = {Vector3.new(0,0,0)}

	while terrain_count < max_chunks and #queue > 0 do
		local pos = table.remove(queue, 1)

		-- check boundaries
		if math.abs(pos.X) > max_dimension or math.abs(pos.Y) > max_dimension or math.abs(pos.Z) > max_dimension then
			continue
		end

		local key = pos.X..","..pos.Y..","..pos.Z
		if visited[key] then continue end
		visited[key] = true

		-- create the chunk
		create_part_reference(pos)
		terrain_count = terrain_count + 1

		-- enqueue neighbors
		for _, dir in ipairs(directions) do
			local neighbor = pos + dir * chunk_size
			table.insert(queue, neighbor)
		end
	end
end

-- // fill chunks with rock, respect blacklist
local function fill_parts_with_rock()
	local terrain_chunks_folder = workspace:WaitForChild("TerrainChunks")
	for _, child in pairs(terrain_chunks_folder:GetChildren()) do
		local pos = child.Position
		local blacklisted = false
		for bl_pos,_ in pairs(blacklists) do
			if bl_pos == pos then
				blacklisted = true
				break
			end
		end

		if not blacklisted then
			terrain_service:FillBlock(
				child.CFrame,
				child.Size,
				Enum.Material.Rock
			)
		else
			-- clear terrain and mark visually
			terrain_service:FillBlock(child.CFrame, child.Size, Enum.Material.Air)
			child.BrickColor = BrickColor.new("Bright red")
		end
	end
end

-- // module start
function module.start_module()
	flood_map_with_parts()
	fill_parts_with_rock()
end

return module