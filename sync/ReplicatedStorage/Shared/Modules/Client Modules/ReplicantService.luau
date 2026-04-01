--!strict
-- @Praxitos

local module = {}

local player_service = game:GetService("Players")

local tool_holsters_reference_folder = game.ReplicatedStorage.Shared.Assets.Guns.Holsters["Tool Holsters"]
local gun_holsters_reference_folder  = game.ReplicatedStorage.Shared.Assets.Guns.Holsters["Gun Holsters"]

local utilities_module = require(
	game.ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Library")
		:WaitForChild("Util")
)

-- Config
local configuration_folder = game.ReplicatedStorage.Shared.Library.Configuration.Scoring_Variables

local empire_folder = configuration_folder.Empire
local empire_rein_count = empire_folder.Empire_Rein_Count
local empire_wave_timer = empire_folder.Empire_Rein_Wave_Timer

local nation_folder = configuration_folder.Nation
local nation_rein_count = nation_folder.Nation_Rein_Count
local nation_wave_timer = nation_folder.Nation_Rein_Wave_Timer

local game_timer = configuration_folder.Timer.Game_Timer
local game_mode = configuration_folder.Gamemode.Gamemode_Type

-- UI
local scoring_gui = player_service.LocalPlayer.PlayerGui:WaitForChild("Scoring")
local main_score_frame = scoring_gui:WaitForChild("scoreframe")

local empire_side_frame = main_score_frame:WaitForChild("empireside")
local nation_side_frame = main_score_frame:WaitForChild("nationside")

local timer_frame = main_score_frame.center
local objective_uis = main_score_frame.objective_uis

local a_point = workspace.Game_Details.Main_Game.Points.A
local b_point = workspace.Game_Details.Main_Game.Points.B
local c_point = workspace.Game_Details.Main_Game.Points.C

local capture_holder = main_score_frame.objective_uis.control

local MAX_REIN = 500 -- // only for scaling

local function setup_light(parent: Instance)
	local light = Instance.new("PointLight")
	light.Brightness = 0.5
	light.Range = 18
	light.Parent = parent
end

local function generate_hair(player: Player, accessorys_folder: Folder)
	for _, child in pairs(accessorys_folder:GetChildren()) do
		-- TODO: implement hair generation
	end
end



local function setup_player(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()

	local gameData_Folder = player:WaitForChild("GameData")
	local accessorys_folder = gameData_Folder:WaitForChild("Accessorys")
	local holsters_folder = accessorys_folder:WaitForChild("Holsters")

	local function on_character(char: Model)
		local torso = char:FindFirstChild("Torso") or char:WaitForChild("Torso")
		setup_light(torso)

		generate_hair(player, accessorys_folder)
	end

	-- Initial
	on_character(character)

	-- Character respawn
	player.CharacterAdded:Connect(on_character)

	holsters_folder.ChildAdded:Connect(function(child: BoolValue)
		local reference =
			tool_holsters_reference_folder:FindFirstChild(child.Name)
			or gun_holsters_reference_folder:FindFirstChild(child.Name)

		if not reference then
			warn("No reference found for holster:", child.Name)
			return
		end

		local primary_part = reference.PrimaryPart
		if not primary_part then
			warn("No primary part for:", child.Name)
			return
		end

		local body_part_name = string.split(primary_part.Name, "_")[2]
		local current_character = player.Character

		if not current_character or not current_character:FindFirstChild(body_part_name) then
			warn("Missing body part:", body_part_name)
			return
		end

		local clone = reference:Clone()

		utilities_module.quick_weld(
			clone.PrimaryPart,
			current_character[body_part_name],
			clone,
			child.Name .. "_Weld"
		)

		clone.Parent = current_character:WaitForChild("CharacterData"):WaitForChild("Rendered_Holsters")

		-- Visibility toggle
		child:GetPropertyChangedSignal("Value"):Connect(function()
			for _, part in pairs(clone:GetDescendants()) do
				if part:IsA("BasePart") and part:GetAttribute("Hide_On_Equip") then
					part.Transparency = child.Value and 0 or 1
				end
			end
		end)
	end)
	
	holsters_folder.ChildRemoved:Connect(function(child)
		local current_character = player.Character
		if not current_character then return end

		local rendered_folder = current_character:FindFirstChild("CharacterData")
			and current_character.CharacterData:FindFirstChild("Rendered_Holsters")

		if not rendered_folder then return end

		local existing = rendered_folder:FindFirstChild(child.Name)
		if existing then
			existing:Destroy()
		end
	end)
end

local function update_bar(frame, value: number)
	local normalized = math.clamp(value / MAX_REIN, 0, 1)
	frame.bar.Size = UDim2.fromScale(normalized, 1)
	frame.num.Text = tostring(value)
end

local function update_wave_text(frame, value: number)
	if value > 0 then
		frame.rein.Text = "Reinforcements in: " .. tostring(value)
	else
		frame.rein.Text = "Reinforcements available"
	end
end

local function update_timer(frame, value: number)
	frame.Text = tostring(value)
end

local function set_objs_invisible()
	for _, ui in pairs(objective_uis:GetChildren()) do
		ui.Visible = false
	end
end

local function update_objective(value: string)
	if not objective_uis:FindFirstChild(string.lower(value)) then
		warn("[REPLICANTSERVICE::] Unable to find the objective ui, returning to control")
		
		set_objs_invisible()
		objective_uis.control.Visible = true
	else
		set_objs_invisible()
		objective_uis[string.lower(value)].Visible = true
	end
end
--////////////////////////////////////////////////////////

function module.start_module()
	-- Setup players
	for _, player in pairs(player_service:GetPlayers()) do
		setup_player(player)
	end

	player_service.PlayerAdded:Connect(setup_player)

	update_bar(nation_side_frame, nation_rein_count.Value)
	update_wave_text(nation_side_frame, nation_wave_timer.Value)

	update_bar(empire_side_frame, empire_rein_count.Value)
	update_wave_text(empire_side_frame, empire_wave_timer.Value)
	
	update_timer(timer_frame, game_timer.Value)
	update_objective(game_mode.Value)
	
	nation_rein_count:GetPropertyChangedSignal("Value"):Connect(function()
		update_bar(nation_side_frame, nation_rein_count.Value)
	end)

	nation_wave_timer:GetPropertyChangedSignal("Value"):Connect(function()
		update_wave_text(nation_side_frame, nation_wave_timer.Value)
	end)

	empire_rein_count:GetPropertyChangedSignal("Value"):Connect(function()
		update_bar(empire_side_frame, empire_rein_count.Value)
	end)

	empire_wave_timer:GetPropertyChangedSignal("Value"):Connect(function()
		update_wave_text(empire_side_frame, empire_wave_timer.Value)
	end)
	
	game_timer:GetPropertyChangedSignal("Value"):Connect(function()
		update_timer(timer_frame, game_timer.Value)
	end)

	game_mode:GetPropertyChangedSignal("Value"):Connect(function()
		update_objective(game_mode.Value)
	end)
	
	for _, child in pairs(a_point.Parent:GetChildren()) do
		child.ChildAdded:Connect(function()
			if objective_uis.control:FindFirstChild("objective" .. child.Name) then
				objective_uis.control:FindFirstChild("objective" .. child.Name).Visible = true
				print("Objective ui found for: " .. child.Name)
			else
				print("Objective ui not found for: " .. child.Name)
			end
		end)
		
		if #child:GetChildren() > 0 then
			if objective_uis.control:FindFirstChild("objective" .. child.Name) then
				objective_uis.control:FindFirstChild("objective" .. child.Name).Visible = true
				print("Objective ui found for: " .. child.Name)
			else
				print("Objective ui not found for: " .. child.Name)
			end
		end
	end
	
	
	game.Players.LocalPlayer.CharacterAdded:Connect(function()
		local player = player_service.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui")

		scoring_gui = playerGui:WaitForChild("Scoring")
		main_score_frame = scoring_gui:WaitForChild("scoreframe")

		empire_side_frame = main_score_frame:WaitForChild("empireside")
		nation_side_frame = main_score_frame:WaitForChild("nationside")

		timer_frame = main_score_frame.center
		objective_uis = main_score_frame.objective_uis

		-- Force refresh UI values
		update_bar(nation_side_frame, nation_rein_count.Value)
		update_wave_text(nation_side_frame, nation_wave_timer.Value)

		update_bar(empire_side_frame, empire_rein_count.Value)
		update_wave_text(empire_side_frame, empire_wave_timer.Value)

		update_timer(timer_frame, game_timer.Value)
		update_objective(game_mode.Value)
	end)
end

return module