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

local animator: Animator = humanoid:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Parent = humanoid
end

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

local current_base_name: string? = nil
local current_state = nil

local is_airborne = false
local crouching = false

-- hip system
local left_hip: Motor6D?
local right_hip: Motor6D?
local hip_adjustment_enabled = true
local current_hip_offset = 0
local target_hip_offset = 0
local hip_adjustment_speed = 0.12

local left_hip_original_c1: CFrame?
local right_hip_original_c1: CFrame?

local ORIGINAL_HIP_HEIGHT = humanoid.HipHeight

--------------------------------------------------
-- LOAD ANIMATIONS
--------------------------------------------------
local function load_animations()
	for _, animation in pairs(animations_table) do
		if not animation then continue end

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
-- HIP INIT
--------------------------------------------------
local function initialize_hips()
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso then
		hip_adjustment_enabled = false
		return
	end

	left_hip = torso:FindFirstChild("Left Hip")
	right_hip = torso:FindFirstChild("Right Hip")

	if not left_hip or not right_hip then
		hip_adjustment_enabled = false
		return
	end

	left_hip_original_c1 = left_hip.C1
	right_hip_original_c1 = right_hip.C1
end

--------------------------------------------------
-- STATE
--------------------------------------------------
local function set_state(new_state)
	if current_state == new_state then
		return false
	end
	current_state = new_state
	return true
end

--------------------------------------------------
-- HIP UPDATE
--------------------------------------------------
local function set_target_hip_offset(offset: number)
	target_hip_offset = offset
end

local function update_hip_offset(dt: number)
	if not hip_adjustment_enabled or not left_hip or not right_hip then return end
	if not left_hip_original_c1 or not right_hip_original_c1 then return end

	local alpha = math.min(dt / hip_adjustment_speed, 1)
	current_hip_offset += (target_hip_offset - current_hip_offset) * alpha

	local left_new = left_hip_original_c1.Position + Vector3.new(0, current_hip_offset, 0)
	local right_new = right_hip_original_c1.Position + Vector3.new(0, current_hip_offset, 0)

	local lx, ly, lz = left_hip_original_c1:ToEulerAnglesXYZ()
	local rx, ry, rz = right_hip_original_c1:ToEulerAnglesXYZ()

	left_hip.C1 = CFrame.new(left_new) * CFrame.Angles(lx, ly, lz)
	right_hip.C1 = CFrame.new(right_new) * CFrame.Angles(rx, ry, rz)

	humanoid.HipHeight = ORIGINAL_HIP_HEIGHT + current_hip_offset
end

--------------------------------------------------
-- BASE / OVERLAY
--------------------------------------------------
local function play_base(name: string, fade: number?, reversed: boolean)
	if current_base_name == name and active_base and active_base.IsPlaying then
		return
	end

	local track = loaded_animations[name]
	if not track then return end

	fade = fade or 0.18

	track:AdjustSpeed(reversed and -1 or 1)

	if active_base then
		active_base:Stop(fade)
	end

	track:Play(fade)
	active_base = track
	current_base_name = name
end

local function play_overlay(name: string, fade: number?)
	local track = loaded_animations[name]
	if not track then return end

	if active_overlays[name] and active_overlays[name].IsPlaying then
		return
	end

	track:Play(fade or 0.12)
	active_overlays[name] = track
end

local function stop_overlay(name: string, fade: number?)
	local track = active_overlays[name]
	if not track then return end

	track:Stop(fade or 0.12)
	active_overlays[name] = nil
end

local function clear_overlays()
	for _, track in pairs(active_overlays) do
		track:Stop(0.12)
	end
	active_overlays = {}
end

--------------------------------------------------
-- MOVEMENT (FIXED STABILITY)
--------------------------------------------------
local function update_movement(speed: number)
	if is_airborne then return end

	local moving = humanoid.MoveDirection.Magnitude > 0.1 and speed > 1

	if not moving then
		local target = crouching and "CROUCH_IDLE" or "IDLE"

		if set_state(target) then
			if crouching then
				play_base("Crouch_Idle")
				set_target_hip_offset(-0.85)
				clear_overlays()
				play_overlay("Crouch_Arms")
			else
				play_base("Stand_Idle")
				set_target_hip_offset(0)
				clear_overlays()
			end
		end
		return
	end

	
	if crouching then
		if set_state("CROUCH_WALK") then
			set_target_hip_offset(-0.85)
			clear_overlays()
			play_overlay("Crouch_Arms")

			if directional_table.Forward then
				play_base("CrouchWalk_Forward")
			elseif directional_table.Left then
				play_base("CrouchWalk_Left")
			elseif directional_table.Right then
				play_base("CrouchWalk_Right")
			else
				play_base("CrouchWalk_Forward")
			end
		end
		return
	end
	
	if speed < 13 then
		if set_state("WALK") then
			set_target_hip_offset(0)
			clear_overlays()

			if directional_table.Forward then
				play_base("Walk_Forward")
			elseif directional_table.Left then
				play_base("Walk_Left")
			elseif directional_table.Right then
				play_base("Walk_Right")
			else
				play_base("Walk_Forward")
			end
		end
		return
	end

	-- SPRINT
	if speed >= 17 then
		if set_state("SPRINT") then
			clear_overlays()
			play_base("Sprint")
			play_overlay("Sprint_Lean")
		end
	end
end

--------------------------------------------------
-- INPUT
--------------------------------------------------
input_service.InputBegan:Connect(function(io, gp)
	if gp then return end

	if io.KeyCode == Enum.KeyCode.W then directional_table.Forward = true end
	if io.KeyCode == Enum.KeyCode.A then directional_table.Left = true end
	if io.KeyCode == Enum.KeyCode.D then directional_table.Right = true end
end)

input_service.InputEnded:Connect(function(io, gp)
	if gp then return end

	if io.KeyCode == Enum.KeyCode.W then directional_table.Forward = false end
	if io.KeyCode == Enum.KeyCode.A then directional_table.Left = false end
	if io.KeyCode == Enum.KeyCode.D then directional_table.Right = false end
end)

--------------------------------------------------
-- CROUCH
--------------------------------------------------
character:GetAttributeChangedSignal("Crouching"):Connect(function()
	crouching = character:GetAttribute("Crouching") == true

	current_state = nil
	current_base_name = nil
	clear_overlays()

	if active_base then
		active_base:Stop(0)
		active_base = nil
	end
end)

--------------------------------------------------
-- LOOP
--------------------------------------------------
run_service.RenderStepped:Connect(function(dt)
	local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
	update_movement(speed)
	update_hip_offset(dt)
end)

--------------------------------------------------
-- HUMANOID STATES
--------------------------------------------------
humanoid.StateChanged:Connect(function(_, new_state)
	if new_state == Enum.HumanoidStateType.Jumping then
		is_airborne = true
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
	end
end)

--------------------------------------------------
-- DEATH
--------------------------------------------------
humanoid.Died:Connect(function()
	if active_base then active_base:Stop(0) end
	clear_overlays()
end)

--------------------------------------------------
-- INIT
--------------------------------------------------
load_animations()
initialize_hips()