--!strict

local Character = script.Parent
local Humanoid: Humanoid = Character:WaitForChild("Humanoid")
local UIS = game:GetService("UserInputService")

local Animations_Folder = game:GetService("ReplicatedStorage")
	.Shared.Assets.Animations.Character

-- Ensure Animator exists
local Animator: Animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
Animator.Parent = Humanoid

-- // CONFIG
local ANIMS = {
	Stand_Idle = Animations_Folder.Idles.Stand_Idle.AnimationId,

	Walk_Forward = Animations_Folder.Walking.Standing.Walk_Forward.AnimationId,
	Walk_Left = Animations_Folder.Walking.Standing.Walk_Left.AnimationId,
	Walk_Right = Animations_Folder.Walking.Standing.Walk_Right.AnimationId,

	Sprint = Animations_Folder.Sprint.Sprint.AnimationId,
	Sprint_Lean = Animations_Folder.Sprint.Sprint_Lean.AnimationId,
	Sprint_Arms = Animations_Folder.Sprint.Sprint_Arms.AnimationId,
	Sprint_Full = Animations_Folder.Sprint.Sprinting_Full.AnimationId,
	
	PrinceRifle_Sprint = Animations_Folder.Sprint.PrinceRifle_Sprint.AnimationId,

	Jump = "rbxassetid://125750702",
	Fall = "rbxassetid://180436148",
}

-- // STATE
local Tracks: {[string]: AnimationTrack} = {}

local ActiveTracks = {
	Base = nil :: AnimationTrack?,
	Overlay = {} :: {[string]: AnimationTrack}
}

local Current_Directions = {
	W = false,
	A = false,
	S = false,
	D = false,
}

local CurrentSpeed = 1

-- // LOAD
local function loadAnimation(name: string, id: string): AnimationTrack
	local anim = Instance.new("Animation")
	anim.Name = name
	anim.AnimationId = id

	local track = Animator:LoadAnimation(anim)

	if name == "Stand_Idle" then
		track.Priority = Enum.AnimationPriority.Idle
	elseif string.find(name, "Walk") or name == "Sprint" then
		track.Priority = Enum.AnimationPriority.Movement
	else
		track.Priority = Enum.AnimationPriority.Action
	end

	return track
end

for name, id in pairs(ANIMS) do
	Tracks[name] = loadAnimation(name, id)
end

-- // BASE
local function playBase(name: string, fade: number?)
	local track = Tracks[name]
	if not track then return end

	if ActiveTracks.Base == track then return end

	if ActiveTracks.Base then
		ActiveTracks.Base:Stop(fade or 0.2)
	end

	track:Play(fade or 0.2)
	ActiveTracks.Base = track
end

-- // OVERLAY
local function playOverlay(name: string, fade: number?)
	if ActiveTracks.Overlay[name] then return end

	local track = Tracks[name]
	if not track then return end

	track:Play(fade or 0.25)
	ActiveTracks.Overlay[name] = track
end

local function stopOverlay(name: string, fade: number?)
	local track = ActiveTracks.Overlay[name]
	if not track then return end

	track:Stop(fade or 0.25)
	ActiveTracks.Overlay[name] = nil
end

local function clearOverlays(fade: number?)
	for name, track in pairs(ActiveTracks.Overlay) do
		track:Stop(fade or 0.25)
		ActiveTracks.Overlay[name] = nil
	end
end

-- // SPEED
local function setBaseSpeed(speed: number)
	if ActiveTracks.Base then
		ActiveTracks.Base:AdjustSpeed(speed)
	end
end

-- // INPUT
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end

	if input.KeyCode == Enum.KeyCode.W then Current_Directions.W = true end
	if input.KeyCode == Enum.KeyCode.A then Current_Directions.A = true end
	if input.KeyCode == Enum.KeyCode.S then Current_Directions.S = true end
	if input.KeyCode == Enum.KeyCode.D then Current_Directions.D = true end
end)

UIS.InputEnded:Connect(function(input, gp)
	if gp then return end

	if input.KeyCode == Enum.KeyCode.W then Current_Directions.W = false end
	if input.KeyCode == Enum.KeyCode.A then Current_Directions.A = false end
	if input.KeyCode == Enum.KeyCode.S then Current_Directions.S = false end
	if input.KeyCode == Enum.KeyCode.D then Current_Directions.D = false end
end)

-- // MOVEMENT
local function detect_sprint_arms_animation()
	-- // expects something like "PrinceRifle"
	if script.Parent:GetAttribute("Sprint_Animation") then
		print("Using custom sprint attribute")
		return ANIMS[script.Parent:GetAttribute("Sprint_Animation") .. "_Sprint"]
	else
		print("Using default sprint animation")
		return ANIMS.Sprint_Arms
	end
end


local function handleMovement(speed: number)
	if speed <= 0.1 then
		clearOverlays(0.3)
		playBase("Stand_Idle", 0.25)
		CurrentSpeed = 1
		return
	end

	local walkspeed = Humanoid.WalkSpeed

	-- WALKING
	if walkspeed < 17 then
		clearOverlays(0.25)

		if Current_Directions.A and not Current_Directions.W then
			playBase("Walk_Left", 0.2)
		elseif Current_Directions.D and not Current_Directions.W then
			playBase("Walk_Right", 0.2)
		else
			playBase("Walk_Forward", 0.2)
		end

		local ratio = math.clamp(speed / walkspeed, 0, 1)
		local targetSpeed = 0.9 + (ratio * 0.2)

		CurrentSpeed = CurrentSpeed + (targetSpeed - CurrentSpeed) * 0.06
		setBaseSpeed(CurrentSpeed)

		return
	end

	-- SPRINT BASE (only when actually moving fast)
	if speed >= 20 then
		playBase("Sprint", 0.2)
	else
		clearOverlays(0.25)
		return
	end

	-- PHASES (WALKSPEED BASED — not raw velocity)
	if walkspeed >= 17 then
		playOverlay("Sprint_Lean", 0.3)
	else
		stopOverlay("Sprint_Lean", 0.3)
	end

	if walkspeed >= 22 then
		playOverlay(detect_sprint_arms_animation(), 0.3)
	else
		stopOverlay("Sprint_Arms", 0.3)
	end

	if walkspeed >= 24 then
		playOverlay("Sprint_Full", 0.3)
	else
		stopOverlay("Sprint_Full", 0.3)
	end

	-- MICRO scaling
	local ratio = math.clamp(speed / walkspeed, 0, 1)
	local targetSpeed = 1 + (ratio * 0.1)

	CurrentSpeed = CurrentSpeed + (targetSpeed - CurrentSpeed) * 0.05
	setBaseSpeed(CurrentSpeed)
end

-- // EVENTS
Humanoid.Running:Connect(handleMovement)

Humanoid.Jumping:Connect(function()
	clearOverlays(0.2)
	playBase("Jump", 0.15)
end)

Humanoid.FreeFalling:Connect(function()
	clearOverlays(0.25)
	playBase("Fall", 0.2)
end)

Humanoid.Died:Connect(function()
	if ActiveTracks.Base then
		ActiveTracks.Base:Stop(0)
	end

	for _, track in pairs(ActiveTracks.Overlay) do
		track:Stop(0)
	end
end)

-- INIT
playBase("Stand_Idle", 0.2)