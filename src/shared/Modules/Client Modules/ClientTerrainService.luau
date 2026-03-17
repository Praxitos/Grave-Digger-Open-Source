--!strict
local module = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local terrain_chunks = workspace:WaitForChild("TerrainChunks")
local TerrainChunkClass = require(ReplicatedStorage.Shared.Library.Classes.TerrainChunkClass)
local LocalPlayer = PlayerService.LocalPlayer

-- Config (hardcoded for simplicity)
local load_distance = 140
local unload_distance = 170
local update_interval = 0.15
local chunks_per_update = 25
local min_visible_chunks = 5
local offscreen_margin = 300
local loads_per_frame = 2

local last_tick = 0
local load_queue = {}

local function queue_load(chunk)
	table.insert(load_queue, chunk)
end

-- Removed render_edits() — Load() now handles edit application directly

local function process_load_queue()
	local i = 0
	while i < loads_per_frame do
		local chunk = table.remove(load_queue, 1)
		if not chunk then break end
		if not chunk.loaded then
			chunk:Load() -- Load() internally applies all edits
			chunk.loaded = true
		end
		i += 1
	end
end

local function chunk_visible(camera, part, margin)
	local half = part.Size / 2
	local center = part.Position
	local viewport = camera.ViewportSize

	local offsets = {
		Vector3.new(0,0,0),
		Vector3.new( half.X, half.Y, half.Z),
		Vector3.new(-half.X, half.Y, half.Z),
		Vector3.new( half.X,-half.Y, half.Z),
		Vector3.new( half.X, half.Y,-half.Z),
		Vector3.new(-half.X,-half.Y, half.Z),
		Vector3.new( half.X,-half.Y,-half.Z),
		Vector3.new(-half.X, half.Y,-half.Z),
		Vector3.new(-half.X,-half.Y,-half.Z)
	}

	for _, offset in ipairs(offsets) do
		local pos, visible = camera:WorldToViewportPoint(center + offset)
		if visible then
			if pos.X > -margin and pos.X < viewport.X + margin
				and pos.Y > -margin and pos.Y < viewport.Y + margin then
				return true
			end
		end
	end

	return false
end

local function chunk_has_entities(chunk_part)
	for _, child in ipairs(chunk_part:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			return true
		end
	end
	return false
end

function module.start_module()

	local chunk_classes_dict: {[string]: TerrainChunkClass.TerrainChunkClass} = {}
	local chunk_list_array: {TerrainChunkClass.TerrainChunkClass} = {}

	for _, part in ipairs(terrain_chunks:GetChildren()) do
		if part:IsA("Part") then
			local chunk = TerrainChunkClass.new({name = part.Name})
			chunk.reference_part = part :: Part
			chunk.loaded = false
			chunk:Unload()
			chunk_classes_dict[part.Name] = chunk
			table.insert(chunk_list_array, chunk)
		end

		local edits_folder = part:WaitForChild("Edits")

		edits_folder.ChildAdded:Connect(function(child)
			if not child:IsA("StringValue") then
				warn(child.Name, "is not a StringValue, returning...")
				return
			end

			local chunk = chunk_classes_dict[part.Name]
			if not chunk then
				warn("ClientTerrainService: No chunk found for part", part.Name)
				return
			end

			local edit_string = child.Value
			table.insert(chunk.edits, edit_string)

			-- Apply the edit immediately to live terrain
			local values = edit_string:split(",")
			local x, y, z = tonumber(values[1]), tonumber(values[2]), tonumber(values[3])
			if x and y and z then
				Workspace.Terrain:FillBall(Vector3.new(x, y, z), 6, Enum.Material.Air)
			end
		end)
	end

	local camera = workspace.CurrentCamera

	RunService.Heartbeat:Connect(function()
		process_load_queue()

		if tick() - last_tick < update_interval then return end
		last_tick = tick()

		local loaded_count = 0
		for _, chunk in ipairs(chunk_list_array) do
			if chunk.loaded then
				loaded_count += 1
			end
		end

		local margin = 0
		if loaded_count < min_visible_chunks then
			margin = offscreen_margin
		end

		local sorted_chunks = {}
		for _, chunk in ipairs(chunk_list_array) do
			local reference = chunk.reference_part
			local distance = (reference.Position - camera.CFrame.Position).Magnitude
			table.insert(sorted_chunks, {chunk = chunk, distance = distance})
		end

		table.sort(sorted_chunks, function(a, b)
			return a.distance < b.distance
		end)

		local processed = 0
		for _, entry in ipairs(sorted_chunks) do
			local chunk = entry.chunk
			local reference = chunk.reference_part
			local distance = entry.distance
			local has_entities = chunk_has_entities(reference)

			if distance > unload_distance then
				if not has_entities and chunk.loaded then
					chunk:Unload()
					chunk.loaded = false
				end
			elseif distance < load_distance then
				if reference.BrickColor == BrickColor.new("Bright red") then
					warn(string.format("ClientTerrainService: Chunk %s is blacklisted", chunk.name))
					continue
				end

				local visible = chunk_visible(camera, reference, margin)
				if visible then
					if not chunk.loaded then
						queue_load(chunk)
					end
				else
					if not has_entities and chunk.loaded and (LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position - chunk.reference_part.Position).Magnitude < 10 then
						chunk:Unload()
						chunk.loaded = false
					else
						if not chunk.loaded then
							queue_load(chunk)
						end
					end
				end
			end

			processed += 1
			if processed >= chunks_per_update then
				break
			end
		end
	end)
end

return module