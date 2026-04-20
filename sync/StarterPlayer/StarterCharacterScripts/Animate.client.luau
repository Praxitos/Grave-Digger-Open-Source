----------------------
-- @Praxitos
-- Animation Handler 
----------------------

-- // Services
local input_service             = game:GetService("UserInputService")
local replicatedstorage_service = game:GetService("ReplicatedStorage")
local run_service               = game:GetService("RunService")
local player_service            = game:GetService("Players")

-- // Variables
local local_player = player_service.LocalPlayer
local character    = script.Parent
local humanoid: Humanoid = character:WaitForChild("Humanoid")
local animator: Animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
animator.Parent = humanoid

local humanoid_root_part = character:WaitForChild("HumanoidRootPart")

local animations_folder = replicatedstorage_service.Shared.Assets.Animations.Character

local animations_table = {
	animations_folder.Idles.Stand_Idle,
	animations_folder.Walking.Standing.Walk_Forward,
	animations_folder.Walking.Standing.Walk_Left,
	animations_folder.Walking.Standing.Walk_Right,

	animations_folder.Jumping.Jump_Arms,
	animations_folder.Jumping.Jump_Land,
	animations_folder.Jumping.Jump_MidAir,

	animations_folder.Sprint.Sprint,
	animations_folder.Sprint.Sprint_Lean,
	animations_folder.Sprint.Sprinting_Full,
	animations_folder.Sprint.Sprint_Arms,
	animations_folder.Sprint.PrinceRifle_Sprint,
	animations_folder.Sprint.GraceRevolver_Sprint,

	animations_folder.Walking.Crouch.CrouchWalk_Forward,
	animations_folder.Walking.Crouch.CrouchWalk_Left,
	animations_folder.Walking.Crouch.CrouchWalk_Right,
	animations_folder.Idles.Crouch_Idle,
	animations_folder.Walking.Crouch.Crouch_Arms
}

local loaded_animations: {[string]: AnimationTrack} = {}
local directional_table = { Forward = false, Left = false, Right = false }

local active_base: AnimationTrack? = nil
local active_overlays: {[string]: AnimationTrack} = {}

local is_airborne = false
local crouching = false

local last_move_time = 0

-- HIP ADJUSTMENT VARIABLES
local left_hip: Motor6D?
local right_hip: Motor6D?
local hip_adjustment_enabled = true
local current_hip_offset = 0
local target_hip_offset = 0
local hip_adjustment_speed = 0.15

-- Store original C1 values to apply offsets relative to them
local left_hip_original_c1: CFrame?
local right_hip_original_c1: CFrame?

local ORIGINAL_HIP_HEIGHT = humanoid.HipHeight 
--------------------------------------------------
-- LOAD
--------------------------------------------------
local function load_animations()
	for _, animation in pairs(animations_table) do
		if not animation then
			warn("[LOAD] NIL animation reference")
			continue
		end

		local track = animator:LoadAnimation(animation)

		if string.find(animation.Name, "Jump") or string.find(animation.Name, "Sprint") then
			track.Priority = Enum.AnimationPriority.Action
		else
			track.Priority = Enum.AnimationPriority.Movement
		end

		if animation.Name == "Jump_MidAir" then
			track.Looped = true
		end

		loaded_animations[animation.Name] = track
	end
end

--------------------------------------------------
-- HIP INITIALIZATION
--------------------------------------------------
local function initialize_hips()
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso then
		warn("[HIP] Could not find Torso or UpperTorso")
		hip_adjustment_enabled = false
		return
	end

	left_hip = torso:FindFirstChild("Left Hip")
	right_hip = torso:FindFirstChild("Right Hip")

	if not left_hip or not right_hip then
		warn("[HIP] Could not find Left Hip or Right Hip Motor6D")
		hip_adjustment_enabled = false
		return
	end

	if not (left_hip:IsA("Motor6D") and right_hip:IsA("Motor6D")) then
		warn("[HIP] Left Hip or Right Hip is not a Motor6D")
		hip_adjustment_enabled = false
		return
	end

	-- Store original C1 positions to calculate offsets from
	left_hip_original_c1 = left_hip.C1
	right_hip_original_c1 = right_hip.C1
end

--------------------------------------------------
-- HIP ADJUSTMENT
--------------------------------------------------
local function set_target_hip_offset(offset: number)
	if not hip_adjustment_enabled or not left_hip or not right_hip then
		return
	end

	target_hip_offset = offset
end

local function update_hip_offset(delta_time: number)
	if not hip_adjustment_enabled or not left_hip or not right_hip or not left_hip_original_c1 or not right_hip_original_c1 then
		return
	end

	-- If already at target, do nothing
	if math.abs(current_hip_offset - target_hip_offset) < 0.001 then
		return
	end

	-- Interpolate towards target offset
	local offset_change = (target_hip_offset - current_hip_offset) * math.min(delta_time / hip_adjustment_speed, 1)
	current_hip_offset = current_hip_offset + offset_change

	local left_new_pos = left_hip_original_c1.Position + Vector3.new(0, current_hip_offset, 0)
	local right_new_pos = right_hip_original_c1.Position + Vector3.new(0, current_hip_offset, 0)

	-- Preserve rotation while updating position
	local left_c1_rot_x, left_c1_rot_y, left_c1_rot_z = left_hip_original_c1:ToEulerAnglesXYZ()
	local right_c1_rot_x, right_c1_rot_y, right_c1_rot_z = right_hip_original_c1:ToEulerAnglesXYZ()

	left_hip.C1 = CFrame.new(left_new_pos) * CFrame.Angles(left_c1_rot_x, left_c1_rot_y, left_c1_rot_z)
	right_hip.C1 = CFrame.new(right_new_pos) * CFrame.Angles(right_c1_rot_x, right_c1_rot_y, right_c1_rot_z)
	
	humanoid.HipHeight = ORIGINAL_HIP_HEIGHT + current_hip_offset
end

--------------------------------------------------
-- BASE
--------------------------------------------------
local function play_base(name: string, fade: number?)
	local track = loaded_animations[name]
	if not track then 
		warn("[BASE] Animation '" .. name .. "' not found in loaded_animations")
		return 
	end

	if active_base == track and track.IsPlaying then
		return
	end

	if active_base then
		active_base:Stop(fade or 0.15)
	end

	track:Play(fade or 0.15)
	active_base = track
end

--------------------------------------------------
-- OVERLAYS
--------------------------------------------------
local function play_overlay(name: string, fade: number?)
	local track = loaded_animations[name]
	if not track then 
		warn("[OVERLAY] Animation '" .. name .. "' not found in loaded_animations")
		return 
	end

	if active_overlays[name] and active_overlays[name].IsPlaying then
		return
	end

	track:Play(fade or 0.15)
	active_overlays[name] = track
end

local function stop_overlay(name: string, fade: number?)
	local track = active_overlays[name]
	if not track then 
		return 
	end

	track:Stop(fade or 0.15)
	active_overlays[name] = nil
end

local function stop_overlays_except(keep_list: {[string]: boolean})
	for name, track in pairs(active_overlays) do
		if not keep_list[name] then
			track:Stop(0.15)
			active_overlays[name] = nil
		end
	end
end

local function clear_overlays()
	for name, track in pairs(active_overlays) do
		track:Stop(0.15)
	end
	active_overlays = {}
end

--------------------------------------------------
-- SPRINT
--------------------------------------------------
local function get_sprint_overlay_name(): string
	local attr = character:GetAttribute("Sprint_Animation")
	if attr then
		local fullName = attr .. "_Sprint"
		if loaded_animations[fullName] then
			return fullName
		end
	end
	return "Sprint_Arms"
end

--------------------------------------------------
-- MOVEMENT
--------------------------------------------------
local function update_movement(speed: number)
	if is_airborne then 
		return 
	end

	local moving = speed > 1 and humanoid.MoveDirection.Magnitude > 0.1

	if moving then
		last_move_time = tick()
	end

	if tick() - last_move_time < 0.1 then
		moving = true
	end

	-- IDLE
	if not moving then
		if crouching then
			play_base("Crouch_Idle")
			set_target_hip_offset(-0.85)

			if not active_overlays["Crouch_Arms"] 
				or not active_overlays["Crouch_Arms"].IsPlaying then
				play_overlay("Crouch_Arms")
			end

			stop_overlays_except({ Crouch_Arms = true })
		else
			play_base("Stand_Idle")
			set_target_hip_offset(0)
			clear_overlays()
		end
		return
	end

	-- CROUCH MOVE
	if crouching then
		set_target_hip_offset(-0.5)
		stop_overlays_except({ Crouch_Arms = true })

		if not active_overlays["Crouch_Arms"] then
			play_overlay("Crouch_Arms")
		end

		if directional_table.Forward then
			play_base("CrouchWalk_Forward")
		elseif directional_table.Left then
			play_base("CrouchWalk_Left")
		elseif directional_table.Right then
			play_base("CrouchWalk_Right")
		else
			play_base("CrouchWalk_Forward")
		end

		return
	end

	-- WALK
	if speed < 13 then
		set_target_hip_offset(0)
		stop_overlays_except({})

		if directional_table.Forward then
			play_base("Walk_Forward")
		elseif directional_table.Left then
			play_base("Walk_Left")
		elseif directional_table.Right then
			play_base("Walk_Right")
		end

		return
	end

	-- SPRINT LEAN
	if speed < 17 then
		set_target_hip_offset(0)
		stop_overlays_except({ Sprint_Lean = true })
		play_overlay("Sprint_Lean")
		return
	end

	-- FULL SPRINT
	set_target_hip_offset(0)
	local sprint_overlay = get_sprint_overlay_name()

	stop_overlays_except({
		Sprint_Lean = true,
		Sprinting_Full = true,
		[sprint_overlay] = true
	})

	play_overlay("Sprint_Lean")
	play_overlay("Sprinting_Full")
	play_overlay(sprint_overlay)
end

--------------------------------------------------
-- INIT
--------------------------------------------------
load_animations()
initialize_hips()

--------------------------------------------------
-- CONNECTIONS
--------------------------------------------------

character:GetAttributeChangedSignal("Crouching"):Connect(function()
	crouching = character:GetAttribute("Crouching") == true

	if active_base then
		active_base:Stop(0)
		active_base = nil
	end

	clear_overlays()

	local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
	update_movement(speed)
end)

run_service.RenderStepped:Connect(function()
	local delta_time = run_service.RenderStepped:Wait()

	local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
	update_movement(speed)

	update_hip_offset(delta_time)
end)

humanoid.StateChanged:Connect(function(_, new_state)
	if new_state == Enum.HumanoidStateType.Jumping then
		is_airborne = true
		set_target_hip_offset(0)
		clear_overlays()
		play_overlay("Jump_Arms")

	elseif new_state == Enum.HumanoidStateType.Freefall then
		is_airborne = true
		play_overlay("Jump_MidAir")

	elseif new_state == Enum.HumanoidStateType.Landed then
		is_airborne = false

		stop_overlay("Jump_MidAir")
		stop_overlay("Jump_Arms")

		play_base("Jump_Land")

		task.delay(0.2, function()
			if not is_airborne then
				active_base = nil
			end
		end)
	end
end)

input_service.InputBegan:Connect(function(io, gp)
	if gp then return end

	if io.KeyCode == Enum.KeyCode.W then 
		directional_table.Forward = true
	end
	if io.KeyCode == Enum.KeyCode.A then 
		directional_table.Left = true
	end
	if io.KeyCode == Enum.KeyCode.D then 
		directional_table.Right = true
	end
end)

input_service.InputEnded:Connect(function(io, gp)
	if gp then return end

	if io.KeyCode == Enum.KeyCode.W then 
		directional_table.Forward = false
	end
	if io.KeyCode == Enum.KeyCode.A then 
		directional_table.Left = false
	end
	if io.KeyCode == Enum.KeyCode.D then 
		directional_table.Right = false
	end
end)

humanoid.Died:Connect(function()
	if active_base then 
		active_base:Stop(0) 
	end
	clear_overlays()
end)