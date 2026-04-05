------------
-- @Praxitos
-- GameManagerService — handles rounds, spawning, and capture point logic
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
local main_game       = workspace.Game_Details.Main_Game
local empire_spawn    = main_game:WaitForChild("Empire")
local nation_spawn    = main_game:WaitForChild("Nation")
local points_folder   = main_game.Points

-- Asset references
local spawn_anims  = shared:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild("Character"):WaitForChild("Spawns")
local core_maps    = shared.Assets.Maps["Core Maps"]

-- Points billboard
local ui_folder = shared.Assets.UI
local points_billboard = ui_folder.Points_Billboard


local testing_boolean = config.Parent.Game_Variables.Testing_Boolean
local visualize_casts_boolean = config.Parent.Ranged_Variables.Visualizations.Visualize_Casts
local fastcast_module = require(shared.Library.Externals.FastCast)

-- State
local time_tick = false


-- Time

local function format_time(total_seconds: number): string
	return string.format("%02d:%02d", math.floor(total_seconds / 60), total_seconds % 60)
end

local function begin_time()
	local total_seconds = 0

	if typeof(game_timer.Value) == "string" then
		local min, sec = string.match(game_timer.Value, "^(%d%d):(%d%d)$")
		if min and sec then
			total_seconds = tonumber(min) * 60 + tonumber(sec)
		end
	end

	while time_tick do
		task.wait(1)
		total_seconds += 1
		game_timer.Value = format_time(total_seconds)
	end
end


-- Spawning

local function get_spawn_animation(spawn_name: string): Animation?
	local folder = spawn_anims:FindFirstChild(spawn_name)
	if not folder then
		warn("[GameManager] No spawn animation folder for:", spawn_name)
		return nil
	end

	local anims = folder:GetChildren()
	if #anims == 0 then
		warn("[GameManager] No animations in spawn folder:", spawn_name)
		return nil
	end

	return anims[math.random(1, #anims)]
end

local function find_empty_spawn(spawn_room: Model): Instance
	for _, slot in pairs(spawn_room.Spawns:GetChildren()) do
		if not slot:GetAttribute("Occupied") then
			return slot
		end
	end

	-- All slots occupied — pick a random one as fallback
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
	print("[GameManager] Spawning reinforcements for:", team.Name)

	local spawn_room = team.Name == "Golden Empire" and empire_spawn or nation_spawn

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Team ~= team or player:GetAttribute("Active") then continue end

		player:SetAttribute("Active", true)
		player:LoadCharacterAsync()

		local character = player.Character or player.CharacterAdded:Wait()
		local slot      = find_empty_spawn(spawn_room)

		slot:SetAttribute("Occupied", true)
		character:PivotTo(slot.CFrame)

		-- Play spawn animation if available
		local anim_track: AnimationTrack?
		local animation = get_spawn_animation(slot.Name)

		if animation then
			local animator = character:WaitForChild("Humanoid"):FindFirstChildOfClass("Animator")
			if animator then
				anim_track = animator:LoadAnimation(animation)
				anim_track:Play()
			end
		end

		local humanoid: Humanoid = character:WaitForChild("Humanoid")

		-- Release slot and stop animation once the player moves
		local move_conn: RBXScriptConnection
		move_conn = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if humanoid.MoveDirection.Magnitude > 0 then
				slot:SetAttribute("Occupied", nil)
				if anim_track then
					anim_track.Looped = false
					anim_track:Stop()
				end
				move_conn:Disconnect()
			end
		end)

		-- Release slot if the player dies before moving
		humanoid.Died:Connect(function()
			slot:SetAttribute("Occupied", nil)
			if anim_track then anim_track:Stop() end
			move_conn:Disconnect()
		end)
	end
end

local function handle_reinforcement_wave(
	rein_count: IntValue,
	wave_timer: IntValue,
	team: Team
)
	while rein_count.Value > 0 do
		task.wait(1)

		if wave_timer.Value > 0 then
			wave_timer.Value -= 1
			continue
		end

		if not has_eligible_players(team) then continue end

		spawn_wave(team)
		rein_count.Value  -= 1
		wave_timer.Value   = 30
	end
end


-- Capture points
local function set_billboard_ui(point_parent: Part)
	local billboard_ui_clone = points_billboard:Clone()
	billboard_ui_clone.Parent = point_parent
end

local function select_random_map(): Model
	local maps = core_maps:GetChildren()
	return maps[math.random(1, #maps)]
end

local function place_map(map: Model, point: Instance)
	map:PivotTo(point.CFrame)
	map.Parent = point
end

local function carve_air_block(map: Model)
	local air = map:FindFirstChild("air")
	if not air then return end
	workspace.Terrain:FillBlock(air.CFrame, air.Size, Enum.Material.Air)
end

local function setup_capture_point(point: Instance, model: Model)
	if not point or not model then return end

	local capture_part: Part = model:FindFirstChild("capture")
	local point_data         = gamemode_folder:FindFirstChild(point.Name .. "_Point")

	if not point_data then
		warn("[GameManager] Missing point data folder for:", point.Name)
		return
	end
	
	set_billboard_ui(point)
	
	local empire_count  = point_data:FindFirstChild(point.Name .. "_Empire_Count")
	local nation_count  = point_data:FindFirstChild(point.Name .. "_Nation_Count")
	local progress      = point_data:FindFirstChild(point.Name .. "_Progress")
	local owner         = point_data:FindFirstChild(point.Name .. "_Owner")

	if not (empire_count and nation_count and progress and owner) then
		warn("[GameManager] Missing value objects in point data:", point_data.Name)
		return
	end


	print("[GameManager] Initialising point:", point.Name)

	-- Track which players are currently inside the zone
	local players_on_point: { [Player]: true } = {}

	local function add_player(player: Player)
		if players_on_point[player] then return end
		players_on_point[player] = true

		if player.Team == game.Teams["Golden Empire"] then
			empire_count.Value += 1
		elseif player.Team == game.Teams["Royal Nation"] then
			nation_count.Value += 1
		end

		print("[GameManager]", point.Name, "entered by", player.Name)
	end

	local function remove_player(player: Player)
		if not players_on_point[player] then return end
		players_on_point[player] = nil

		if player.Team == game.Teams["Golden Empire"] then
			empire_count.Value -= 1
		elseif player.Team == game.Teams["Royal Nation"] then
			nation_count.Value -= 1
		end

		print("[GameManager]", point.Name, "left by", player.Name)
	end

	local function get_player_from_hit(hit: BasePart): Player?
		local character = hit.Parent
		if not character or not character:FindFirstChild("Humanoid") then return nil end
		return Players:GetPlayerFromCharacter(character)
	end

	capture_part.Touched:Connect(function(hit)
		local player = get_player_from_hit(hit)
		if player then add_player(player) end
	end)

	capture_part.TouchEnded:Connect(function(hit)
		local player = get_player_from_hit(hit)
		if player then remove_player(player) end
	end)

	-- Capture loop
	task.spawn(function()
		while true do
			task.wait(1)

			local empire_n = empire_count.Value
			local nation_n = nation_count.Value
			local total    = empire_n + nation_n

			-- Award ownership at full progress
			if progress.Value == 20 then
				if empire_n > nation_n then
					owner.Value = "Golden Empire"
					print("[GameManager] Point captured by Empire:", point.Name)
				elseif nation_n > empire_n then
					owner.Value = "Royal Nation"
					print("[GameManager] Point captured by Nation:", point.Name)
				else
					owner.Value = ""
				end
				progress.Value = 0
			end

			-- Decay when nobody is on the point
			if total == 0 then
				if progress.Value > 0 then
					progress.Value -= 1
				end
				continue
			end

			-- Stall when teams are even
			if empire_n == nation_n then
				print("[GameManager]", point.Name, "contested — stalling.")
				continue
			end

			-- Advance for whichever team has more players, unless they already own it
			if empire_n > nation_n then
				if owner.Value == "Golden Empire" then continue end
				progress.Value += 1
				print("[GameManager]", point.Name, "being capped by Empire.")
			else
				if owner.Value == "Royal Nation" then continue end
				progress.Value += 1
				print("[GameManager]", point.Name, "being capped by Nation.")
			end
		end
	end)
end


-- Module entry

function module.start_module()
	print("[GameManager] Running initial startup!")
	
	fastcast_module.VisualizeCasts = visualize_casts_boolean.Value
	
	visualize_casts_boolean:GetPropertyChangedSignal("Value"):Connect(function()
		fastcast_module.VisualizeCasts = visualize_casts_boolean.Value
		print("[GameManager] Cast visualization set to", visualize_casts_boolean.Value)
	end)
	
	
	if testing_boolean.Value == true then return end

	time_tick = true
	task.spawn(begin_time)

	local empire_team = game.Teams["Golden Empire"]
	local nation_team = game.Teams["Royal Nation"]

	task.spawn(handle_reinforcement_wave, empire_rein_count, empire_rein_wave_timer, empire_team)
	task.spawn(handle_reinforcement_wave, nation_rein_count, nation_rein_wave_timer, nation_team)

	-- Assign a random map to each active capture point
	local available_points = points_folder:GetChildren()
	local active_points: { Instance } = {}

	for i = 1, capture_points_count.Value do
		local map = select_random_map()

		local point
		repeat
			point = available_points[math.random(1, #available_points)]
		until #point:GetChildren() == 0

		place_map(map, point)
		carve_air_block(map)
		setup_capture_point(point, map)
		table.insert(active_points, point)
		print("[GameManager] Placed map at point:", point.Name)
	end

	-- Ticket drain loop
	-- Every 3 seconds, each point owned by a team drains (3 * P / n) tickets from
	-- the enemy, where P = points owned by that team and n = total active points.
	-- Example with n=3: each point drains 1 ticket  (3*1/3, 3*2/3, 3*3/3 per point owned)
	-- Example with n=2: each point drains 1.5 tickets (3*1/2, 3*2/2)
	-- Example with n=1: the sole point drains 3 tickets (3*1/1)
	task.spawn(function()
		local n = #active_points

		while true do
			task.wait(3)

			local empire_owned = 0
			local nation_owned = 0

			for _, point in ipairs(active_points) do
				local point_data = gamemode_folder:FindFirstChild(point.Name .. "_Point")
				if not point_data then continue end

				local owner = point_data:FindFirstChild(point.Name .. "_Owner")
				if not owner then continue end

				if owner.Value == "Golden Empire" then
					empire_owned += 1
				elseif owner.Value == "Royal Nation" then
					nation_owned += 1
				end
			end

			-- Empire-owned points drain (3 * empire_owned / n) tickets each from Nation
			if empire_owned > 0 then
				local drain_per_point = (3 * empire_owned) / n
				local total_drain     = drain_per_point * empire_owned
				nation_rein_count.Value = math.max(0, nation_rein_count.Value - total_drain)
				print(string.format(
					"[GameManager] Empire owns %d/%d points — draining %.2f tickets from Nation (%.2f per point).",
					empire_owned, n, total_drain, drain_per_point
					))
			end

			-- Nation-owned points drain (3 * nation_owned / n) tickets each from Empire
			if nation_owned > 0 then
				local drain_per_point = (3 * nation_owned) / n
				local total_drain     = drain_per_point * nation_owned
				empire_rein_count.Value = math.max(0, empire_rein_count.Value - total_drain)
				print(string.format(
					"[GameManager] Nation owns %d/%d points — draining %.2f tickets from Empire (%.2f per point).",
					nation_owned, n, total_drain, drain_per_point
					))
			end
		end
	end)
end

return module