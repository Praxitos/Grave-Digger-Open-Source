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

-- // Constants
local time_tick = false

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

local function has_available_players(team: Team): boolean
	for _, player in ipairs(players_service:GetPlayers()) do
		if player.Team == team and not player:GetAttribute("Active") then
			return true
		end
	end

	return false
end

local function spawn_reinforcements(team: Team, tag: string)
	local count = 0
	
	for _, player in ipairs(players_service:GetPlayers()) do
		if player:GetAttribute("Active") then continue end

		if player.Team and player.Team == team then
			player:LoadCharacterAsync()
			player:SetAttribute("Active", true)
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
end

return module
