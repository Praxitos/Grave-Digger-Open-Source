------------
-- @Praxitos
-- GameManagerService — handles rounds, spawning, and control point logic
------------

local module = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

-- Shared folders
local shared        = ReplicatedStorage.Shared
local library       = shared.Library
local config        = library.Configuration.Scoring_Variables

-- Scoring values
local empire_rein_count      = config.Empire.Empire_Rein_Count
local empire_rein_wave_timer = config.Empire.Empire_Rein_Wave_Timer
local nation_rein_count      = config.Nation.Nation_Rein_Count
local nation_rein_wave_timer = config.Nation.Nation_Rein_Wave_Timer
local game_timer             = config.Timer.Game_Timer
local gamemode_folder        = config.Gamemode
local capture_points_count   = gamemode_folder.Capture_Points_Count

-- Workspace references
local main_game     = workspace.Game_Details.Main_Game
local empire_spawn  = main_game:WaitForChild("Empire")
local nation_spawn  = main_game:WaitForChild("Nation")
local points_folder = main_game.Points

-- Assets
local spawn_anims = shared.Assets.Animations.Character.Spawns
local core_maps   = shared.Assets.Maps["Core Maps"]

-- State
local time_tick = false
local active_points = {}

-- Decimal buffers (for IntValue safety)
local empire_buffer = 0
local nation_buffer = 0

--------------------------------------------------
-- Time
--------------------------------------------------

local function format_time(total_seconds: number): string
	return string.format("%02d:%02d", math.floor(total_seconds / 60), total_seconds % 60)
end

local function begin_time()
	local total_seconds = 0

	while time_tick do
		task.wait(1)
		total_seconds += 1
		game_timer.Value = format_time(total_seconds)
	end
end

--------------------------------------------------
-- Spawning (unchanged core logic)
--------------------------------------------------

local function find_empty_spawn(spawn_room: Model): Instance
	for _, slot in pairs(spawn_room.Spawns:GetChildren()) do
		if not slot:GetAttribute("Occupied") then
			return slot
		end
	end
	local slots = spawn_room.Spawns:GetChildren()
	return slots[math.random(1, #slots)]
end

local function has_eligible_players(team: Team): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Team == team and not player:GetAttribute("Active") then
			return true
		end
	end
	return false
end

local function spawn_wave(team: Team)
	local spawn_room = team.Name == "Golden Empire" and empire_spawn or nation_spawn

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Team ~= team or player:GetAttribute("Active") then continue end

		player:SetAttribute("Active", true)
		player:LoadCharacterAsync()

		local character = player.Character or player.CharacterAdded:Wait()
		local slot      = find_empty_spawn(spawn_room)

		slot:SetAttribute("Occupied", true)
		character:PivotTo(slot.CFrame)

		local humanoid = character:WaitForChild("Humanoid")

		local move_conn
		move_conn = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if humanoid.MoveDirection.Magnitude > 0 then
				slot:SetAttribute("Occupied", nil)
				move_conn:Disconnect()
			end
		end)

		humanoid.Died:Connect(function()
			slot:SetAttribute("Occupied", nil)
			move_conn:Disconnect()
		end)
	end
end

local function handle_reinforcement_wave(rein_count, wave_timer, team)
	while rein_count.Value > 0 do
		task.wait(1)

		if wave_timer.Value > 0 then
			wave_timer.Value -= 1
			continue
		end

		if not has_eligible_players(team) then continue end

		spawn_wave(team)
		rein_count.Value -= 1
		wave_timer.Value = 30
	end
end

--------------------------------------------------
-- Capture System (FIXED)
--------------------------------------------------

local function get_players_in_zone(part: BasePart)
	local list = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end

		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local relative = part.CFrame:PointToObjectSpace(root.Position)
		local half = part.Size / 2

		if math.abs(relative.X) <= half.X
			and math.abs(relative.Y) <= half.Y
			and math.abs(relative.Z) <= half.Z then
			table.insert(list, player)
		end
	end

	return list
end

local function setup_capture_point(point: Instance, model: Model)
	local capture_part = model:FindFirstChild("capture")
	if not capture_part then return end

	local point_data = gamemode_folder:FindFirstChild(point.Name .. "_Point")
	if not point_data then return end

	local empire_count = point_data:FindFirstChild(point.Name .. "_Empire_Count")
	local nation_count = point_data:FindFirstChild(point.Name .. "_Nation_Count")
	local progress     = point_data:FindFirstChild(point.Name .. "_Progress")
	local owner        = point_data:FindFirstChild(point.Name .. "_Owner")

	if not (empire_count and nation_count and progress and owner) then return end

	table.insert(active_points, {
		point = point,
		owner = owner
	})

	task.spawn(function()
		while true do
			task.wait(1)

			local players = get_players_in_zone(capture_part)

			local empire_n = 0
			local nation_n = 0

			for _, player in ipairs(players) do
				if player.Team == game.Teams["Golden Empire"] then
					empire_n += 1
				elseif player.Team == game.Teams["Royal Nation"] then
					nation_n += 1
				end
			end

			empire_count.Value = empire_n
			nation_count.Value = nation_n

			local total = empire_n + nation_n

			if progress.Value >= 20 then
				if empire_n > nation_n then
					owner.Value = "Golden Empire"
				elseif nation_n > empire_n then
					owner.Value = "Royal Nation"
				else
					owner.Value = ""
				end
				progress.Value = 0
			end

			if total == 0 then
				if progress.Value > 0 then
					progress.Value -= 1
				end
				continue
			end

			if empire_n == nation_n then continue end

			if empire_n > nation_n then
				if owner.Value ~= "Golden Empire" then
					progress.Value += 1
				end
			else
				if owner.Value ~= "Royal Nation" then
					progress.Value += 1
				end
			end
		end
	end)
end

--------------------------------------------------
-- Ticket Drain (NEW CORE SYSTEM)
--------------------------------------------------

local function handle_ticket_drain()
	while true do
		task.wait(3)

		local total_points = #active_points
		if total_points == 0 then continue end

		local empire_points = 0
		local nation_points = 0

		for _, data in ipairs(active_points) do
			if data.owner.Value == "Golden Empire" then
				empire_points += 1
			elseif data.owner.Value == "Royal Nation" then
				nation_points += 1
			end
		end

		local empire_drain = 3 * (nation_points / total_points)
		local nation_drain = 3 * (empire_points / total_points)

		-- Apply buffered drain
		empire_buffer += empire_drain
		nation_buffer += nation_drain

		local e_whole = math.floor(empire_buffer)
		local n_whole = math.floor(nation_buffer)

		empire_buffer -= e_whole
		nation_buffer -= n_whole

		empire_rein_count.Value = math.max(0, empire_rein_count.Value - e_whole)
		nation_rein_count.Value = math.max(0, nation_rein_count.Value - n_whole)

		-- Win condition
		if empire_rein_count.Value <= 0 then
			print("[GameManager] Nation Wins!")
			time_tick = false
			break
		elseif nation_rein_count.Value <= 0 then
			print("[GameManager] Empire Wins!")
			time_tick = false
			break
		end
	end
end

--------------------------------------------------
-- Map Placement (FIXED)
--------------------------------------------------

local function select_random_map()
	local maps = core_maps:GetChildren()
	return maps[math.random(1, #maps)]
end

local function place_map(map, point)
	local clone = map:Clone()
	clone:PivotTo(point.CFrame)
	clone.Parent = point
	return clone
end

--------------------------------------------------
-- Start
--------------------------------------------------

function module.start_module()
	print("[GameManager] Starting")

	time_tick = true
	task.spawn(begin_time)

	local empire_team = game.Teams["Golden Empire"]
	local nation_team = game.Teams["Royal Nation"]

	task.spawn(handle_reinforcement_wave, empire_rein_count, empire_rein_wave_timer, empire_team)
	task.spawn(handle_reinforcement_wave, nation_rein_count, nation_rein_wave_timer, nation_team)

	task.spawn(handle_ticket_drain)

	local available_points = points_folder:GetChildren()
	local used = {}

	for i = 1, capture_points_count.Value do
		local point

		repeat
			point = available_points[math.random(1, #available_points)]
		until not used[point]

		used[point] = true

		local map = select_random_map()
		local placed = place_map(map, point)

		setup_capture_point(point, placed)
	end
end

return module