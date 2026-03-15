local module = {}

--------------------------------------------------
-- SERVICES
--------------------------------------------------
local run_service = game:GetService("RunService")

--------------------------------------------------
-- REFERENCES
--------------------------------------------------
local terrain_chunks = workspace:WaitForChild("TerrainChunks")

local terrain_chunk_class = require(
	game:GetService("ReplicatedStorage").Shared.Library.Classes.TerrainChunkClass
)

--------------------------------------------------
-- CONFIG
--------------------------------------------------
local LOAD_DISTANCE = 140
local UNLOAD_DISTANCE = 170

local UPDATE_INTERVAL = 0.15
local CHUNKS_PER_UPDATE = 25

local MIN_VISIBLE_CHUNKS = 15
local OFFSCREEN_MARGIN = 1000

--------------------------------------------------
-- VARIABLES
--------------------------------------------------
local last_tick = 0

local chunk_classes = {}
local chunk_list = {}

local load_queue = {}

--------------------------------------------------
-- LOAD QUEUE
--------------------------------------------------
local function queue_load(chunk)
	table.insert(load_queue, chunk)
end

local function process_load_queue()
	local loads_per_frame = 2
	for i = 1, loads_per_frame do
		local chunk = table.remove(load_queue, 1)
		if not chunk then break end
		if not chunk.loaded then
			chunk:Load()
			chunk.loaded = true
		end
	end
end

--------------------------------------------------
-- VISIBILITY CHECK (center + 8 corners)
--------------------------------------------------
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

	for _,offset in ipairs(offsets) do
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

--------------------------------------------------
-- CHECK IF CHUNK HAS ENTITIES
--------------------------------------------------
local function chunk_has_entities(chunk_part)
	for _,child in ipairs(chunk_part:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			return true
		end
	end
	return false
end

--------------------------------------------------
-- MODULE START
--------------------------------------------------
function module.start_module()
	print("[CLIENT_TERRAIN_SERVICE::] Starting Client Terrain Service...")

	--------------------------------------------------
	-- CREATE CHUNK CLASSES
	--------------------------------------------------
	for _,part in pairs(terrain_chunks:GetChildren()) do
		if part:IsA("Part") then
			local chunk = terrain_chunk_class.new({name = part.Name})
			chunk.reference_part = part
			chunk.loaded = false
			chunk:Unload()
			chunk_classes[part.Name] = chunk
			table.insert(chunk_list, chunk)
		end
	end

	local camera = workspace.CurrentCamera

	--------------------------------------------------
	-- STREAM LOOP
	--------------------------------------------------
	run_service.Heartbeat:Connect(function()
		process_load_queue()

		if tick() - last_tick < UPDATE_INTERVAL then return end
		last_tick = tick()

		-- count currently loaded chunks
		local loaded_count = 0
		for _,chunk in pairs(chunk_list) do
			if chunk.loaded then
				loaded_count += 1
			end
		end

		-- if too few loaded chunks, expand offscreen margin
		local margin = 0
		if loaded_count < MIN_VISIBLE_CHUNKS then
			margin = OFFSCREEN_MARGIN
		end

		-- prepare distance-sorted list of chunks
		local sorted_chunks = {}
		for _,chunk in ipairs(chunk_list) do
			local reference = chunk.reference_part
			local distance = (reference.Position - camera.CFrame.Position).Magnitude
			table.insert(sorted_chunks, {chunk = chunk, distance = distance})
		end

		table.sort(sorted_chunks, function(a,b)
			return a.distance < b.distance
		end)

		-- process a limited number of chunks per update
		local processed = 0
		for _,entry in ipairs(sorted_chunks) do
			local chunk = entry.chunk
			local reference = chunk.reference_part
			local distance = entry.distance
			local has_entities = chunk_has_entities(reference)

			--------------------------------------------------
			-- FAR AWAY
			--------------------------------------------------
			if distance > UNLOAD_DISTANCE then
				if not has_entities and chunk.loaded then
					chunk:Unload()
					chunk.loaded = false
				end

			--------------------------------------------------
			-- CLOSE ENOUGH
			--------------------------------------------------
			elseif distance < LOAD_DISTANCE then
				if reference.BrickColor == BrickColor.new("Bright red") then
					warn("[CLIENT_TERRAIN_SERVICE::] Chunk ", chunk.name, " is blacklisted and cannot be loaded.")
					continue
				end

				local visible = chunk_visible(camera, reference, margin)
				if visible then
					if not chunk.loaded then
						queue_load(chunk)
					end
				else
					if not has_entities and chunk.loaded then
						chunk:Unload()
						chunk.loaded = false
					end
				end
			end

			processed += 1
			if processed >= CHUNKS_PER_UPDATE then
				break
			end
		end
	end)
end

return module