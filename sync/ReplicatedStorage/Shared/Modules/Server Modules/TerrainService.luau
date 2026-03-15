--!strict
local module = {}

local terrain = workspace.Terrain
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local delete_terrain: RemoteEvent = ReplicatedStorage.Shared.Library.Events.Terrain_Communication.Delete_Terrain

-- Config
local max_chunks = 200
local chunk_size = 32
local max_dimension = 320

local blacklists = {
	[Vector3.new(0,0,0)] = true
}

local function flood_map_with_parts()
	local terrain_folder = Instance.new("Folder")
	terrain_folder.Name = "TerrainChunks"
	terrain_folder.Parent = workspace

	local terrain_count = 0

	local function create_part_reference(position)
		local terrain_chunk = Instance.new("Part")
		terrain_chunk.Name = "TerrainChunk" .. terrain_count
		terrain_chunk.Size = Vector3.new(chunk_size, chunk_size, chunk_size)
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
	local queue = {Vector3.new(0,0,0)}

	while terrain_count < max_chunks and #queue > 0 do
		local pos = table.remove(queue, 1)

		if math.abs(pos.X) > max_dimension or math.abs(pos.Y) > max_dimension or math.abs(pos.Z) > max_dimension then
			continue
		end

		local key = pos.X..","..pos.Y..","..pos.Z
		if visited[key] then continue end
		visited[key] = true

		create_part_reference(pos)
		terrain_count += 1

		for _, dir in ipairs(directions) do
			local neighbor = pos + dir * chunk_size
			table.insert(queue, neighbor)
		end
	end
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

		delete_terrain.OnServerEvent:Connect(function(player, position)

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
		string_value.Value = string.format("%f,%f,%f", position.X, position.Y, position.Z)
		string_value.Parent = edits_folder

	end)
end

return module
