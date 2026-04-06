-- @Praxitos

local module = {}

-- Services
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

-- Shared references
local shared    = ReplicatedStorage:WaitForChild("Shared")
local library   = shared:WaitForChild("Library")
local utilities = require(library:WaitForChild("Util"))

-- Asset folders
local holsters_root = ReplicatedStorage.Shared.Assets.Guns.Holsters
local tool_holsters = holsters_root["Tool Holsters"]
local gun_holsters  = holsters_root["Gun Holsters"]

-- Configuration
local config          = library.Configuration.Scoring_Variables
local empire_config   = config.Empire
local nation_config   = config.Nation
local game_timer_val  = config.Timer.Game_Timer
local gamemode_config = config.Gamemode

local empire_rein_count = empire_config.Empire_Rein_Count
local empire_wave_timer = empire_config.Empire_Rein_Wave_Timer
local nation_rein_count = nation_config.Nation_Rein_Count
local nation_wave_timer = nation_config.Nation_Rein_Wave_Timer

local visualize_casts_boolean = config.Parent.Ranged_Variables.Visualizations.Visualize_Casts
local fastcast_module = require(shared.Library.Externals.FastCast)

-- Constants
local MAX_REIN = 500

local ICONS = {
	Golden_Empire_Background = "rbxassetid://17519166341",
	Royal_Nation_Background  = "rbxassetid://17519166185",
}

local FLASH_TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local FLASH_COLOR      = Color3.fromRGB(220, 50, 50)

local replicant_folder = game:GetService("ReplicatedStorage").Shared.Library.Events.Replicant_Communication
local fastcast_replicant = replicant_folder.FastCast_Connection
local vfx_replicant = replicant_folder.VFX_Connection
local sfx_replicant = replicant_folder.SFX_Connection
local texture_replicant = replicant_folder.Texture_Connection

-- UI references (reassigned on respawn)
local scoring_gui:        ScreenGui
local score_frame:        Frame
local empire_frame:       Frame
local nation_frame:       Frame
local timer_frame:        Frame
local objective_uis:      Folder
local overhead_frame:     Frame
local overhead_bar:       Frame
local overhead_bgicon:    ImageLabel
local overhead_label:     TextLabel
local overhead_enemyin:   Frame
local overhead_lockicon:  ImageLabel

local local_player = Players.LocalPlayer

-- Overhead sync connections; cleared whenever the player leaves a capture zone
local overhead_connections: { RBXScriptConnection } = {}

-- Active flash tweens keyed by frame, so we can stop them individually
local active_flash_tweens: { [Frame]: Tween } = {}
local flash_connections: { [Frame]: RBXScriptConnection } = {}

-- Tracks the last team that was actively pushing each point, keyed by point name.
-- Preserved during decay so the bar keeps the correct color as it falls back.
local point_cap_team: { [string]: string } = {}


-- Helpers

local function setup_light(parent: BasePart)
	local light      = Instance.new("PointLight")
	light.Brightness = 0.5
	light.Range      = 18
	light.Parent     = parent
end

local function update_bar(frame: Frame, value: number)
	local normalized = math.clamp(value / MAX_REIN, 0, 1)
	frame.bar.Size   = UDim2.fromScale(normalized, 1)
	frame.num.Text   = tostring(value)
end

local function update_wave_text(frame: Frame, value: number)
	frame.rein.Text = value > 0
		and "Reinforcements in: " .. tostring(value)
		or  "Reinforcements available"
end

local function update_timer(frame: TextLabel, value: number)
	frame.Text = tostring(value)
end

local function set_objectives_hidden()
	for _, ui in pairs(objective_uis:GetChildren()) do
		ui.Visible = false
	end
end

local function update_objective(value: string)
	set_objectives_hidden()
	local target = objective_uis:FindFirstChild(string.lower(value))
	if target then
		target.Visible = true
	else
		warn("[ScoringClient] Unknown objective type:", value, "— falling back to 'control'")
		local control = objective_uis:FindFirstChild("control")
		if control then control.Visible = true end
	end
end

local function refresh_ui()
	update_bar(nation_frame, nation_rein_count.Value)
	update_wave_text(nation_frame, nation_wave_timer.Value)
	update_bar(empire_frame, empire_rein_count.Value)
	update_wave_text(empire_frame, empire_wave_timer.Value)
	update_timer(timer_frame, game_timer_val.Value)
	update_objective(gamemode_config.Gamemode_Type.Value)
end

local function rebind_ui()
	local player_gui  = local_player:WaitForChild("PlayerGui")
	scoring_gui       = player_gui:WaitForChild("Scoring")
	score_frame       = scoring_gui:WaitForChild("scoreframe")
	empire_frame      = score_frame:WaitForChild("empireside")
	nation_frame      = score_frame:WaitForChild("nationside")
	timer_frame       = score_frame.center
	objective_uis     = score_frame.objective_uis
	overhead_frame    = scoring_gui.objpopup
	overhead_bar      = overhead_frame:FindFirstChild("bar")
	overhead_bgicon   = overhead_frame:FindFirstChild("bgicon")
	overhead_label    = overhead_frame:FindFirstChild("label")
	overhead_enemyin  = overhead_frame:FindFirstChild("enemyin")
	overhead_lockicon = overhead_frame:FindFirstChild("lockicon")
	refresh_ui()
end


-- Flash helpers

local function start_flash(frame: Frame)
	if active_flash_tweens[frame] then return end

	frame.BackgroundColor3                  = FLASH_COLOR
	frame.BackgroundTransparency            = 1
	overhead_enemyin.BackgroundTransparency = 1

	frame.Visible            = true
	overhead_enemyin.Visible = true

	local tween = TweenService:Create(frame, FLASH_TWEEN_INFO, {
		BackgroundTransparency = 0
	})
	active_flash_tweens[frame] = tween
	tween:Play()

	if flash_connections[frame] then
		flash_connections[frame]:Disconnect()
	end
	flash_connections[frame] = frame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		overhead_enemyin.BackgroundTransparency = frame.BackgroundTransparency
	end)
end

local function stop_flash(frame: Frame)
	local tween = active_flash_tweens[frame]
	if tween then
		tween:Cancel()
		active_flash_tweens[frame] = nil
	end

	if flash_connections[frame] then
		flash_connections[frame]:Disconnect()
		flash_connections[frame] = nil
	end

	frame.BackgroundTransparency            = 1
	frame.Visible                           = false
	overhead_enemyin.BackgroundTransparency = 1
	overhead_enemyin.Visible                = false
end

local function update_enemy_flash(
	empire_count: IntValue,
	nation_count: IntValue,
	owner: StringValue,
	scoreboard_enemyin: Frame
)
	local team = local_player.Team
	if not team then
		stop_flash(scoreboard_enemyin)
		return
	end

	local enemy_present = false
	local enemy_owns    = false

	if team.Name == "Golden Empire" then
		enemy_present = nation_count.Value > 0
		enemy_owns    = owner.Value == "Royal Nation"
	else
		enemy_present = empire_count.Value > 0
		enemy_owns    = owner.Value == "Golden Empire"
	end

	if enemy_present and not enemy_owns then
		start_flash(scoreboard_enemyin)
	else
		stop_flash(scoreboard_enemyin)
	end
end


-- Player setup

local function setup_holster(player: Player, child: BoolValue)
	local reference =
		tool_holsters:FindFirstChild(child.Name) or
		gun_holsters:FindFirstChild(child.Name)

	if not reference then
		warn("[ScoringClient] No holster reference found for:", child.Name)
		return
	end

	local primary = reference.PrimaryPart
	if not primary then
		warn("[ScoringClient] No PrimaryPart on holster:", child.Name)
		return
	end

	local body_part_name = string.split(primary.Name, "_")[2]
	local char = player.Character
	if not char or not char:FindFirstChild(body_part_name) then
		warn("[ScoringClient] Missing body part:", body_part_name)
		return
	end

	local clone = reference:Clone()
	utilities.quick_weld(clone.PrimaryPart, char[body_part_name], clone, child.Name .. "_Weld")
	clone.Parent = char:WaitForChild("CharacterData"):WaitForChild("Rendered_Holsters")

	child:GetPropertyChangedSignal("Value"):Connect(function()
		for _, part in pairs(clone:GetDescendants()) do
			if part:IsA("BasePart") and part:GetAttribute("Hide_On_Equip") then
				part.Transparency = child.Value and 0 or 1
			end
		end
	end)
end

local function remove_holster(player: Player, child: Instance)
	local char = player.Character
	if not char then return end
	local rendered = char:FindFirstChild("CharacterData")
		and char.CharacterData:FindFirstChild("Rendered_Holsters")
	if not rendered then return end
	local existing = rendered:FindFirstChild(child.Name)
	if existing then existing:Destroy() end
end

local function on_character_added(char: Model)
	local torso = char:FindFirstChild("Torso") or char:WaitForChild("Torso")
	setup_light(torso)
end

local function setup_player(player: Player)
	local char = player.Character or player.CharacterAdded:Wait()
	on_character_added(char)
	player.CharacterAdded:Connect(on_character_added)

	local game_data   = player:WaitForChild("GameData")
	local accessories = game_data:WaitForChild("Accessorys")
	local holsters    = accessories:WaitForChild("Holsters")

	holsters.ChildAdded:Connect(function(child) setup_holster(player, child) end)
	holsters.ChildRemoved:Connect(function(child) remove_holster(player, child) end)
end


-- Capture point UI

local function clear_overhead_connections()
	for _, conn in ipairs(overhead_connections) do
		conn:Disconnect()
	end
	table.clear(overhead_connections)
end

-- Returns the bar color for whichever team last pushed this point
local function get_cap_color(team_name: string?): Color3
	if team_name == "Golden Empire" then
		return Color3.new(1, 1, 0)
	elseif team_name == "Royal Nation" then
		return Color3.fromRGB(167, 83, 170)
	end
	-- Neutral fallback — progress should be 0 at this point anyway
	return Color3.fromRGB(167, 83, 170)
end

-- Applies progress to a bar.
-- Updates the remembered capping team when someone is actively pushing,
-- and leaves it unchanged during decay so the color persists.
local function apply_progress(
	point_name: string,
	progress_value: number,
	empire_count: IntValue,
	nation_count: IntValue,
	bar: Frame,
	sync_overhead: boolean
)
	local empire_n = empire_count.Value
	local nation_n = nation_count.Value

	if empire_n > nation_n then
		point_cap_team[point_name] = "Golden Empire"
	elseif nation_n > empire_n then
		point_cap_team[point_name] = "Royal Nation"
	end
	-- Nobody pushing (decay) → point_cap_team[point_name] unchanged

	-- Forget the team once the bar fully resets
	if progress_value == 0 then
		point_cap_team[point_name] = nil
	end

	local color = get_cap_color(point_cap_team[point_name])
	local size  = UDim2.fromScale(1, progress_value / 20)

	bar.BackgroundColor3 = color
	bar.Size             = size

	if sync_overhead then
		overhead_bar.BackgroundColor3 = color
		overhead_bar.Size             = size
	end
end

local function apply_owner(
	owner_value: string,
	bar: Frame, bg_icon: ImageLabel, point_label: TextLabel,
	sync_overhead: boolean
)
	if owner_value == "Golden Empire" then
		local color = Color3.fromRGB(255, 255, 0)
		bg_icon.Image          = ICONS.Golden_Empire_Background
		bg_icon.Visible        = true
		bg_icon.ImageColor3    = color
		point_label.TextColor3 = color
		if sync_overhead then
			overhead_bgicon.Image       = ICONS.Golden_Empire_Background
			overhead_bgicon.Visible     = true
			overhead_bgicon.ImageColor3 = color
			overhead_label.TextColor3   = color
		end
	elseif owner_value == "Royal Nation" then
		local color = Color3.fromRGB(146, 25, 167)
		bg_icon.Image          = ICONS.Royal_Nation_Background
		bg_icon.Visible        = true
		bg_icon.ImageColor3    = color
		point_label.TextColor3 = color
		if sync_overhead then
			overhead_bgicon.Image       = ICONS.Royal_Nation_Background
			overhead_bgicon.Visible     = true
			overhead_bgicon.ImageColor3 = color
			overhead_label.TextColor3   = color
		end
	else
		bg_icon.Visible = false
		if sync_overhead then overhead_bgicon.Visible = false end
	end
end

local function sync_overhead_to_point(point_name: string)
	clear_overhead_connections()

	local folder = gamemode_config:FindFirstChild(point_name .. "_Point")
	if not folder then
		warn("[ScoringClient] sync_overhead: missing folder for:", point_name)
		return
	end

	local empire_count = folder:FindFirstChild(point_name .. "_Empire_Count")
	local nation_count = folder:FindFirstChild(point_name .. "_Nation_Count")
	local progress     = folder:FindFirstChild(point_name .. "_Progress")
	local owner        = folder:FindFirstChild(point_name .. "_Owner")

	local control_ui         = objective_uis.control:FindFirstChild("objective" .. point_name)
	local bar                = control_ui and control_ui:FindFirstChild("bar")     :: Frame
	local bg_icon            = control_ui and control_ui:FindFirstChild("bgicon")  :: ImageLabel
	local point_label        = control_ui and control_ui:FindFirstChild("label")   :: TextLabel
	local scoreboard_enemyin = control_ui and control_ui:FindFirstChild("enemyin") :: Frame

	overhead_label.Text = point_name
	apply_owner(owner.Value, bar, bg_icon, point_label, true)
	apply_progress(point_name, progress.Value, empire_count, nation_count, bar, true)
	update_enemy_flash(empire_count, nation_count, owner, scoreboard_enemyin)

	table.insert(overhead_connections, progress.Changed:Connect(function()
		apply_progress(point_name, progress.Value, empire_count, nation_count, bar, true)
	end))
	table.insert(overhead_connections, owner.Changed:Connect(function()
		apply_owner(owner.Value, bar, bg_icon, point_label, true)
		update_enemy_flash(empire_count, nation_count, owner, scoreboard_enemyin)
	end))
	table.insert(overhead_connections, empire_count.Changed:Connect(function()
		update_enemy_flash(empire_count, nation_count, owner, scoreboard_enemyin)
	end))
	table.insert(overhead_connections, nation_count.Changed:Connect(function()
		update_enemy_flash(empire_count, nation_count, owner, scoreboard_enemyin)
	end))
end

local function bind_point_ui(point_name: string, control_ui: Frame)
	local folder = gamemode_config:FindFirstChild(point_name .. "_Point")
	if not folder then
		warn("[ScoringClient] Missing gamemode folder for:", point_name)
		return
	end

	local empire_count       = folder:FindFirstChild(point_name .. "_Empire_Count")
	local nation_count       = folder:FindFirstChild(point_name .. "_Nation_Count")
	local progress           = folder:FindFirstChild(point_name .. "_Progress")
	local owner              = folder:FindFirstChild(point_name .. "_Owner")
	local scoreboard_enemyin = control_ui:FindFirstChild("enemyin") :: Frame

	local bar: Frame             = control_ui:FindFirstChild("bar")
	local bg_icon: ImageLabel    = control_ui:FindFirstChild("bgicon")
	local point_label: TextLabel = control_ui:FindFirstChild("label")

	progress.Changed:Connect(function()
		apply_progress(point_name, progress.Value, empire_count, nation_count, bar, false)
	end)
	owner.Changed:Connect(function()
		apply_owner(owner.Value, bar, bg_icon, point_label, false)
		update_enemy_flash(empire_count, nation_count, owner, scoreboard_enemyin)
	end)

	update_enemy_flash(empire_count, nation_count, owner, scoreboard_enemyin)

	empire_count.Changed:Connect(function()
		update_enemy_flash(empire_count, nation_count, owner, scoreboard_enemyin)
	end)
	nation_count.Changed:Connect(function()
		update_enemy_flash(empire_count, nation_count, owner, scoreboard_enemyin)
	end)
end

local function bind_capture_point_proximity(model: Model, point_name: string)
	local capture = model:FindFirstChild("capture")
	if not capture then return end

	capture.Touched:Connect(function(hit)
		if hit.Parent ~= local_player.Character then return end
		if overhead_frame.Visible then return end
		overhead_frame.Visible = true
		sync_overhead_to_point(point_name)
	end)

	capture.TouchEnded:Connect(function(hit)
		if hit.Parent ~= local_player.Character then return end
		if not overhead_frame.Visible then return end
		overhead_frame.Visible = false
		stop_flash(overhead_enemyin)
		clear_overhead_connections()
	end)
end

local function handle_point_child(point_child: Instance)
	local control = objective_uis.control:FindFirstChild("objective" .. point_child.Name)
	if not control then
		warn("[ScoringClient] No objective UI found for:", point_child.Name)
		return
	end

	control.Visible = true
	bind_point_ui(point_child.Name, control)

	local model = point_child:FindFirstChildWhichIsA("Model")
	if model then
		bind_capture_point_proximity(model, point_child.Name)
	end
end

local function watch_all_points()
	local points_folder = workspace.Game_Details.Main_Game.Points
	for _, point in pairs(points_folder:GetChildren()) do
		point.ChildAdded:Connect(function() handle_point_child(point) end)
		if #point:GetChildren() > 0 then
			handle_point_child(point)
		end
	end
end


-- Module entry

function module.start_module()
	rebind_ui()
	
	fastcast_module.VisualizeCasts = visualize_casts_boolean.Value

	visualize_casts_boolean:GetPropertyChangedSignal("Value"):Connect(function()
		fastcast_module.VisualizeCasts = visualize_casts_boolean.Value
		print("[GameManager] Cast visualization set to", visualize_casts_boolean.Value)
	end)

	for _, player in pairs(Players:GetPlayers()) do
		setup_player(player)
	end
	Players.PlayerAdded:Connect(setup_player)

	nation_rein_count:GetPropertyChangedSignal("Value"):Connect(function()
		update_bar(nation_frame, nation_rein_count.Value)
	end)
	nation_wave_timer:GetPropertyChangedSignal("Value"):Connect(function()
		update_wave_text(nation_frame, nation_wave_timer.Value)
	end)
	empire_rein_count:GetPropertyChangedSignal("Value"):Connect(function()
		update_bar(empire_frame, empire_rein_count.Value)
	end)
	empire_wave_timer:GetPropertyChangedSignal("Value"):Connect(function()
		update_wave_text(empire_frame, empire_wave_timer.Value)
	end)
	game_timer_val:GetPropertyChangedSignal("Value"):Connect(function()
		update_timer(timer_frame, game_timer_val.Value)
	end)
	gamemode_config.Gamemode_Type:GetPropertyChangedSignal("Value"):Connect(function()
		update_objective(gamemode_config.Gamemode_Type.Value)
	end)

	local_player.CharacterAdded:Connect(rebind_ui)

	watch_all_points()
	
	fastcast_replicant.OnClientEvent:Connect(function(...)
		local args = {...}
		local player = args[1]
		local origin = args[2]
		local direction = args[3]
		local speed = args[4]
		local cast_data = args[5]
		
		if player.Name == local_player.Name then return end
	
		local caster, caster_data = utilities.setupFastCast(cast_data)
		local cast = caster:Fire(origin + Vector3.new(5,5,5), direction, speed, caster_data)
	end)
	
	vfx_replicant.OnClientEvent:Connect(function(...)
			local args = {...}
			
			local effect = args[2]
			local CFrame_Value = args[3]
			local target_tables = args[4]
			local parent = args[5]
			local emit_count = args[6]
			local attach_to_parent = args[7]
			
			
			emit_count = emit_count or 10

			for _, child in pairs(effect:GetDescendants()) do

			local match = table.find(target_tables, child.Name) 
				or table.find(target_tables, child.ClassName)

			if not match then
				continue
			end

			local clone = child:Clone()
			local container: Instance = parent

			if attach_to_parent then
				clone.Parent = parent
			else
				local part = Instance.new("Part")
				part.Size = Vector3.new(0.05, 0.05, 0.05)
				part.Anchored = true
				part.CanCollide = false
				part.Transparency = 1
				part.Parent = workspace

				part.CFrame = CFrame_Value

				clone.Parent = part
				container = part
			end


			if clone:IsA("ParticleEmitter") then
				clone.Enabled = true
				clone:Emit(emit_count)

				-- Cleanup based on lifetime
				local lifetime = clone.Lifetime.Max

				task.delay(lifetime + 0.1, function()
					if attach_to_parent then
						if clone then
							clone:Destroy()
						end
					else
						if container then
							container:Destroy()
						end
					end
				end)
			end
		end
	end)
	
	texture_replicant.OnClientEvent:Connect(function(...)
		local args = {...}

		local part = args[1]
		local position = args[2]
		local normal = args[3]
		local parent = args[4]
		
		local texture_clone = part:Clone()
		texture_clone.CFrame = CFrame.new(position, position + normal)
		texture_clone.Parent = parent
	end)
end

return module