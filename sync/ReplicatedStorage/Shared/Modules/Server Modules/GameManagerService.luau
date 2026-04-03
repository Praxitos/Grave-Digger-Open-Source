------------
-- @Praxitos
-- GameManager, handles rounds, spawning players, etc.
------------

local module = {}

-- // Services
local replicatedstorage_service = game:GetService("ReplicatedStorage")
local players_service = game:GetService("Players")

-- // Vars
local shared_folder = replicatedstorage_service.Shared
local library_folder = shared_folder.Library
local configuration_folder = library_folder.Configuration
local scoring_variables = configuration_folder.Scoring_Variables

local empire_folder = scoring_variables.Empire
local empire_rein_count = empire_folder.Empire_Rein_Count
local empire_rein_wave_timer = empire_folder.Empire_Rein_Wave_Timer


local nation_folder = scoring_variables.Nation
local nation_rein_count = nation_folder.Nation_Rein_Count
local nation_rein_wave_timer = nation_folder.Nation_Rein_Wave_Timer

local timer_folder = scoring_variables.Timer
local game_timer = timer_folder.Game_Timer

local empire_spawn_room = workspace.Game_Details.Main_Game:WaitForChild("Empire")
local nation_spawn_room = workspace.Game_Details.Main_Game:WaitForChild("Nation")

local spawns_folder = shared_folder:WaitForChild("Assets"):WaitForChild('Animations'):WaitForChild("Character"):WaitForChild("Spawns")


local gamemode_folder = scoring_variables.Gamemode
local capture_points_count = gamemode_folder.Capture_Points_Count

local core_maps_folder = shared_folder.Assets.Maps["Core Maps"]

local main_game_folder = workspace.Game_Details.Main_Game
local points_folder = main_game_folder.Points


-- // Constants
local time_tick = false

-- // Ticket drain state
-- Tracks the current owner of each active capture point by name
-- e.g. { A = "Golden Empire", B = "", C = "Royal Nation" }
local point_owners: { [string]: string } = {}
local total_points_on_map = 0

-- // Funcs
-- // formats time specially for the huge countdown
local function format_time(total_seconds: number): string
	local minutes = math.floor(total_seconds / 60)
	local seconds = total_seconds % 60

	return string.format("%02d:%02d", minutes, seconds)
end

-- // Overall game time
local function begin_time()
	-- expects game_timer.Value to start as "00:00" or nil

	local total_seconds = 0

	-- if there's already a value, parse it
	if typeof(game_timer.Value) == "string" then
		local min, sec = string.match(game_timer.Value, "^(%d%d):(%d%d)$")
		if min and sec then
			total_seconds = tonumber(min) * 60 + tonumber(sec)
		end
	end

	while time_tick == true do
		task.wait(1)

		total_seconds += 1

		game_timer.Value = format_time(total_seconds)
	end
end

----------------------------
-- SPAWNING HANDLING -------
----------------------------
local function has_available_players(team: Team): boolean
	for _, player in ipairs(players_service:GetPlayers()) do
		if player.Team == team and not player:GetAttribute("Active") then
			return true
		end
	end

	return false
end

local function get_animation(spawn_name)
	if not spawns_folder:FindFirstChild(spawn_name) then warn("No spawn folder for " .. spawn_name) return end
	local animations = spawns_folder[spawn_name]:GetChildren()
	if #animations == 0 then warn("No animations in " .. spawn_name) return end
	return animations[math.random(1, #animations)]
end

local function find_empty_spot(spawnroom: Model)
	for _, spawns in pairs(spawnroom.Spawns:GetChildren()) do
		if not spawns:GetAttribute("Occupied") then
			print("Found empty spot: " .. spawns.Name)
			return spawns
		else
			print("Spot " .. spawns.Name .. " is occupied")
		end
	end
	
	-- // all slots filled, so just pick a random one
	local spawns = spawnroom.Spawns:GetChildren()
	return spawns[math.random(1, #spawns)]
end

local function spawn_reinforcements(team: Team, tag: string)
	print("[GameManager::] Spawning reinforcements for " .. team.Name)

	for _, player in ipairs(players_service:GetPlayers()) do
		if player:GetAttribute("Active") then
			continue
		end

		if player.Team == team then
			player:SetAttribute("Active", true)

			-- Load character safely
			player:LoadCharacterAsync()
			local character = player.Character or player.CharacterAdded:Wait()

			-- Determine spawn container
			local spawn_container
			if team.Name == "Golden Empire" then
				spawn_container = empire_spawn_room
			else
				spawn_container = nation_spawn_room
			end

			-- Get empty spawn slot
			local spawn_slot = find_empty_spot(spawn_container)
			if not spawn_slot then
				warn("No available spawn slots")
				continue
			end

			-- Mark occupied
			spawn_slot:SetAttribute("Occupied", true)

			-- Move character
			character:PivotTo(spawn_slot.CFrame)

			-- Play animation
			local animation = get_animation(spawn_slot.Name)
			local animTrack

			if animation then
				local humanoid = character:WaitForChild("Humanoid")
				local animator = humanoid:FindFirstChildOfClass("Animator")

				if animator then
					animTrack = animator:LoadAnimation(animation)
					animTrack:Play()
				end
			end

			-- Movement detection with threshold
			local Humanoid: Humanoid = character:WaitForChild("Humanoid")

			local conn
			conn = Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
				if Humanoid.MoveDirection.Magnitude > 0 then
					spawn_slot:SetAttribute("Occupied", nil)

					if animTrack then
						animTrack.Looped = false
						animTrack:Stop()
					end

					if conn then
						conn:Disconnect()
						conn = nil
					end
				end
			end)

			-- Cleanup if character dies early
			character:WaitForChild("Humanoid").Died:Connect(function()
				spawn_slot:SetAttribute("Occupied", nil)

				if animTrack then
					animTrack:Stop()
				end

				if conn then
					conn:Disconnect()
				end
			end)
		end
	end
end

local function handle_reinforcements(
	rein_count: IntValue,
	wave_timer: IntValue,
	team: Team,
	tag: string
)
	while rein_count.Value > 0 do
		task.wait(1)

		if wave_timer.Value > 0 then
			wave_timer.Value -= 1
		else
			-- WAIT until at least one player is eligible
			if not has_available_players(team) then
				continue
			end

			spawn_reinforcements(team, tag)

			rein_count.Value -= 1

			wave_timer.Value = 30
		end
	end

end


----------------------------
-- POINT ESTABILISHMENTS --
----------------------------
-- // returns random  point map
local function select_random_map()
	local spawns = core_maps_folder:GetChildren()
	return spawns[math.random(1, #spawns)]
end

local function place_map(model, target_point)
	model:PivotTo(target_point.CFrame)
	model.Parent = target_point
end

local function fill_air_block(model)
	local air_part = model:FindFirstChild("air")
	
	game.Workspace.Terrain:FillBlock(air_part.CFrame, air_part.Size, Enum.Material.Air)
end

local function detect_point_handling(point: Instance, model: Model)
	if not point or not model then return end

	local capture_part: Part = model:FindFirstChild("capture")
	local folder_point = gamemode_folder:FindFirstChild(point.Name .. "_Point")

	local empirecount_numbervalue = folder_point:FindFirstChild(point.Name .. "_Empire_Count")
	local nationcount_numbervalue = folder_point:FindFirstChild(point.Name .. "_Nation_Count")
	local progress_numbervalue = folder_point:FindFirstChild(point.Name .. "_Progress")
	local owner_stringvalue = folder_point:FindFirstChild(point.Name .. "_Owner")

	if not (empirecount_numbervalue and nationcount_numbervalue and progress_numbervalue and owner_stringvalue) then
		warn("[GameManager::] Missing value objects in:", folder_point.Name)
		return
	end

	print("[Point Init]:", point.Name)

	local player_count = 0
	local players_in_point = {} -- [player] = true

	local function add_player(player: Player)
		if players_in_point[player] then return end -- already counted

		players_in_point[player] = true
		player_count += 1

		local team = player.Team
		if team == game.Teams["Golden Empire"] then
			empirecount_numbervalue.Value += 1
		elseif team == game.Teams["Royal Nation"] then
			nationcount_numbervalue.Value += 1
		end

		print("[Point Init]:", point.Name, "entered by", player.Name)
	end

	local function remove_player(player: Player)
		if not players_in_point[player] then return end -- not tracked

		players_in_point[player] = nil
		player_count -= 1

		local team = player.Team
		if team == game.Teams["Golden Empire"] then
			empirecount_numbervalue.Value -= 1
		elseif team == game.Teams["Royal Nation"] then
			nationcount_numbervalue.Value -= 1
		end

		print("[Point Init]:", point.Name, "left by", player.Name)
	end

	capture_part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		local player = game.Players:GetPlayerFromCharacter(character)
		if not player then return end

		add_player(player)
	end)

	capture_part.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		local player = game.Players:GetPlayerFromCharacter(character)
		if not player then return end

		remove_player(player)
	end)
	
	---------------- Loop
	task.spawn(function()
		while true do
			task.wait(1) 

			-- // take ownership
			if progress_numbervalue.Value == 20 then
					if empirecount_numbervalue.Value > nationcount_numbervalue.Value then
					owner_stringvalue.Value = "Golden Empire"
					point_owners[point.Name] = "Golden Empire"
					print("[GameManager::] set owner as Empire for:", point.Name)
				elseif nationcount_numbervalue.Value > empirecount_numbervalue.Value then
					owner_stringvalue.Value = "Royal Nation"
					point_owners[point.Name] = "Royal Nation"
					print("[GameManager::] set owner as Nation for:", point.Name)
				else
					owner_stringvalue.Value = ""
					point_owners[point.Name] = ""
				end
				
			
				progress_numbervalue.Value = 0
			end



			if player_count <= 0 then	
				if progress_numbervalue.Value > 0 then
					progress_numbervalue.Value -= 1
				end

				continue
			end

			if empirecount_numbervalue.Value == nationcount_numbervalue.Value then
				print("[GameManager::]", point.Name, "stalling... equal numbers.")
				continue
			end

			if empirecount_numbervalue.Value > nationcount_numbervalue.Value then
				if owner_stringvalue.Value == "Golden Empire" then
					continue -- already owned by empire
				end
				progress_numbervalue.Value += 1
				print("[GameManager::]", point.Name, "Being capped by empire.")
			elseif nationcount_numbervalue.Value > empirecount_numbervalue.Value then
				if owner_stringvalue.Value == "Royal Nation" then
					continue -- already owned by nation
				end
				progress_numbervalue.Value += 1
				print("[GameManager::]", point.Name, "Being capped by nation.")
			end
			
			
			
		end
	end)
end

----------------------------
-- TICKET DRAIN LOOP ------
----------------------------
-- Every 3 seconds, each point owned by a team drains (3 * P / n) tickets
-- from the ENEMY team, where P = points owned by enemy, n = total points.
local function start_ticket_drain()
	while time_tick do
		task.wait(3)

		if total_points_on_map == 0 then continue end

		-- Count how many points each team owns
		local empire_owned = 0
		local nation_owned = 0

		for _, owner in pairs(point_owners) do
			if owner == "Golden Empire" then
				empire_owned += 1
			elseif owner == "Royal Nation" then
				nation_owned += 1
			end
		end

		-- Empire-owned points drain Nation tickets
		-- Total drain = 3 * empire_owned / n  (each point drains 3/n)
		if empire_owned > 0 then
			local total_drain = (3 * empire_owned) / total_points_on_map
			local floored = math.floor(total_drain)
			if floored > 0 then
				local new_value = math.max(0, nation_rein_count.Value - floored)
				if new_value ~= nation_rein_count.Value then
					print("[GameManager::] Draining", floored, "tickets from Nation ("
						.. empire_owned .. "/" .. total_points_on_map .. " points held by Empire)")
					nation_rein_count.Value = new_value
				end
			end
		end

		-- Nation-owned points drain Empire tickets
		-- Total drain = 3 * nation_owned / n  (each point drains 3/n)
		if nation_owned > 0 then
			local total_drain = (3 * nation_owned) / total_points_on_map
			local floored = math.floor(total_drain)
			if floored > 0 then
				local new_value = math.max(0, empire_rein_count.Value - floored)
				if new_value ~= empire_rein_count.Value then
					print("[GameManager::] Draining", floored, "tickets from Empire ("
						.. nation_owned .. "/" .. total_points_on_map .. " points held by Nation)")
					empire_rein_count.Value = new_value
				end
			end
		end
	end
end


function module.start_module()
	print("[GameManager::] Running initial startup!")

	time_tick = true

	task.spawn(begin_time)

	local empire_team = game.Teams["Golden Empire"]
	local nation_team = game.Teams["Royal Nation"]

	task.spawn(function()
		handle_reinforcements(
			empire_rein_count,
			empire_rein_wave_timer,
			empire_team,
			"Empire"
		)
	end)

	task.spawn(function()
		handle_reinforcements(
			nation_rein_count,
			nation_rein_wave_timer,
			nation_team,
			"Nation"
		)
	end)
	
	
	-- // for loop on the capture point count
	total_points_on_map = capture_points_count.Value

	for i = 1, capture_points_count.Value do
		local map = select_random_map()
		local point_table = points_folder:GetChildren()

		local point

		repeat
			point = point_table[math.random(1, #point_table)]
		until #point:GetChildren() == 0

		-- Register this point in the owner tracker
		point_owners[point.Name] = ""

		place_map(map, point)
		fill_air_block(map)
		detect_point_handling(point, map)
		print("Placed map at point: " .. point.Name)
	end

	-- Start the ticket drain loop
	task.spawn(start_ticket_drain)
end

return module
