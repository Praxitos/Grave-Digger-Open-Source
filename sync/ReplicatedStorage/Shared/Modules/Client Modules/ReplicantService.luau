-- @Praxitos

local module = {}

-- Services
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- Constants
local MAX_REIN = 500

local ICONS = {
	Golden_Empire_Background = "rbxassetid://17519166341",
	Royal_Nation_Background  = "rbxassetid://17519166185",
}

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
local overhead_enemyin:   TextLabel
local overhead_lockicon:  ImageLabel

local local_player = Players.LocalPlayer

-- Overhead sync connections; cleared whenever the player leaves a capture zone
local overhead_connections: { RBXScriptConnection } = {}


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

-- Applies owner state to a scoreboard control UI; mirrors to overhead when sync_overhead is true
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

-- Applies progress state to a scoreboard bar; mirrors to overhead when sync_overhead is true
local function apply_progress(
	progress_value: number,
	empire_gt_nation: boolean,
	bar: Frame,
	sync_overhead: boolean
)
	local color = empire_gt_nation
		and Color3.new(1, 1, 0)
		or  Color3.fromRGB(167, 83, 170)
	local size = UDim2.fromScale(1, progress_value / 20)

	bar.BackgroundColor3 = color
	bar.Size             = size

	if sync_overhead then
		overhead_bar.BackgroundColor3 = color
		overhead_bar.Size             = size
	end
end

-- Syncs the overhead UI to mirror a specific point, live until the player exits the zone
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

	local control_ui  = objective_uis.control:FindFirstChild("objective" .. point_name)
	local bar         = control_ui and control_ui:FindFirstChild("bar")    :: Frame
	local bg_icon     = control_ui and control_ui:FindFirstChild("bgicon") :: ImageLabel
	local point_label = control_ui and control_ui:FindFirstChild("label")  :: TextLabel

	-- Immediate sync on entry so the overhead never shows stale state
	apply_owner(owner.Value, bar, bg_icon, point_label, true)
	apply_progress(progress.Value, empire_count.Value > nation_count.Value, bar, true)

	table.insert(overhead_connections, progress.Changed:Connect(function()
		apply_progress(progress.Value, empire_count.Value > nation_count.Value, bar, true)
	end))
	table.insert(overhead_connections, owner.Changed:Connect(function()
		apply_owner(owner.Value, bar, bg_icon, point_label, true)
	end))

	overhead_label.Text = point_name
end

local function bind_point_ui(point_name: string, control_ui: Frame)
	local folder = gamemode_config:FindFirstChild(point_name .. "_Point")
	if not folder then
		warn("[ScoringClient] Missing gamemode folder for:", point_name)
		return
	end

	local empire_count = folder:FindFirstChild(point_name .. "_Empire_Count")
	local nation_count = folder:FindFirstChild(point_name .. "_Nation_Count")
	local progress     = folder:FindFirstChild(point_name .. "_Progress")
	local owner        = folder:FindFirstChild(point_name .. "_Owner")

	local bar: Frame             = control_ui:FindFirstChild("bar")
	local bg_icon: ImageLabel    = control_ui:FindFirstChild("bgicon")
	local point_label: TextLabel = control_ui:FindFirstChild("label")

	progress.Changed:Connect(function()
		apply_progress(progress.Value, empire_count.Value > nation_count.Value, bar, false)
	end)

	owner.Changed:Connect(function()
		apply_owner(owner.Value, bar, bg_icon, point_label, false)
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
end

return module