--!strict

-- // Services
local InputService      = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local PlayerService     = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- // References
local CameraClass = require(script.Parent.Parent.Parent.Parent.Library.Classes.CameraClass)

------------------------------------------------------------------------
-- TUNING
------------------------------------------------------------------------

local PITCH_CLAMP_MIN = math.rad(-70)
local PITCH_CLAMP_MAX = math.rad(70)

-- OTS position smoothing
local CAM_SMOOTH_SPEED    = 20

-- OTS offsets (fallbacks if OffsetFolder values are missing)
local DEFAULT_DISTANCE    = 5
local DEFAULT_SIDE        = 1.8
local DEFAULT_HEIGHT      = 1.6
local SHOULDER_LERP_SPEED = 14

-- Sprint pull-back
local SPRINT_DISTANCE_ADD = 1.2
local SPRINT_THRESHOLD    = 17
local SPRINT_MAX_SPEED    = 24

-- FOV
local BASE_FOV  = 70
local MAX_FOV   = 80
local FOV_SPEED = 4

-- Scroll zoom
-- Player scrolls to adjust OTS distance within [ZOOM_MIN, ZOOM_MAX].
-- Each scroll tick moves the target by ZOOM_STEP studs.
-- The camera lerps to the new target at ZOOM_LERP_SPEED.
local ZOOM_MIN        = 2
local ZOOM_MAX        = 6
local ZOOM_STEP       = 0.6
local ZOOM_LERP_SPEED = 10

-- Collision
local COLLISION_OFFSET = 0.25

-- Free-look
-- Camera smoothly pans from its current position to the head on entry,
-- then the mouse drives the orbit freely — exactly like shift-lock but for
-- looking around. No RMB required; mouse moves camera immediately.
local FREELOOK_PAN_SPEED      = 8     -- lerp speed during pan-to-head phase
local FREELOOK_PAN_THRESHOLD  = 0.25  -- studs: close enough = pan done
local FREELOOK_ORBIT_DISTANCE = 5     -- studs back from head during orbit

-- Debounces
local FIRST_PERSON_DEBOUNCE = 0.2
local SHOULDER_DEBOUNCE     = 0.2
-- Alt fires TWO InputBegan events per physical press (key + OS modifier).
-- This debounce swallows the second so the toggle doesn't flip ON then OFF.
local FREELOOK_DEBOUNCE     = 0.15


------------------------------------------------------------------------
-- Module + locals
------------------------------------------------------------------------

local BaseCamera  = setmetatable({}, {__index = CameraClass})
local LocalPlayer = PlayerService.LocalPlayer
local Camera      = Workspace.CurrentCamera

local OffsetFolder =
	ReplicatedStorage.Shared.Library.Configuration.Character_Variables.Camera.BaseCamera

local PlayerData   = LocalPlayer:WaitForChild("PlayerData")
local SettingsData = PlayerData:WaitForChild("Settings Data")
local InputOptions = SettingsData:WaitForChild("Input Options")

local Shoulder_Switch = InputOptions:WaitForChild("Shoulder Switch")
local Free_Look       = InputOptions:WaitForChild("Free Look")
local First_Person    = InputOptions:WaitForChild("First Person")

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function getOffset(name: string, default: number): number
	local inst = OffsetFolder:FindFirstChild(name)
	if inst and inst:IsA("NumberValue") then return inst.Value end
	return default
end

local function getKeyName(value: string): string
	return value:gsub("Enum.KeyCode.", "")
end

-- Handles "Alt" / "LeftAlt" / "RightAlt" all matching each other
local function keyMatches(pressed: string, binding: string): boolean
	if pressed == binding then return true end
	local altSet = { Alt = true, LeftAlt = true, RightAlt = true }
	if altSet[pressed] and altSet[binding] then return true end
	return false
end

local function yawFromLook(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

local function lerp(a: number, b: number, speed: number, dt: number): number
	return a + (b - a) * (1 - math.exp(-speed * dt))
end

local function lerpVec(a: Vector3, b: Vector3, speed: number, dt: number): Vector3
	return a:Lerp(b, 1 - math.exp(-speed * dt))
end

-- Returns the head world position, falling back gracefully
local function getHeadPos(character: Model): Vector3
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head.Position end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position + Vector3.new(0, 1.5, 0)) or Vector3.zero
end

------------------------------------------------------------------------
-- Constructor
------------------------------------------------------------------------

function BaseCamera.new(cameraInfo)
	local self = CameraClass.new(cameraInfo)
	setmetatable(self, {__index = BaseCamera})
	self.CameraPosition = Camera.CFrame.Position
	return self
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------

function BaseCamera:Start()

	Camera.CameraType             = Enum.CameraType.Scriptable
	LocalPlayer.CameraMode        = Enum.CameraMode.Classic
	InputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
	InputService.MouseIconEnabled = false

	-- OTS angles
	self.CameraYaw   = 0
	self.CameraPitch = 0

	-- Free-look
	--   IsFreeLook     : mode active flag
	--   FreeLookPhase  : "panning"  = camera moving to head on entry
	--                    "orbiting" = mouse freely drives the camera
	--   FreeLookDebounce: blocks the duplicate Alt event Roblox fires
	self.IsFreeLook      = false
	self.FreeLookPhase   = "orbiting"
	self.FreeLookYaw     = 0
	self.FreeLookPitch   = 0
	self.FreeLookDebounce = false

	-- First-person
	self.IsFirstPerson       = false
	self.FirstPersonDebounce = false

	-- Shoulder
	self.RightShoulderOffset = getOffset("sideOffset", DEFAULT_SIDE)
	self.LeftShoulderOffset  = -getOffset("sideOffset", DEFAULT_SIDE)
	self.IsRightShoulder     = true
	self.TargetShoulder      = self.RightShoulderOffset
	self.CurrentShoulder     = self.TargetShoulder
	self.ShoulderDebounce    = false

	-- Distance (scroll-adjusted; clamped to [ZOOM_MIN, ZOOM_MAX])
	self.BaseDistance    = getOffset("distanceBehind", DEFAULT_DISTANCE)
	self.BaseDistance    = math.clamp(self.BaseDistance, ZOOM_MIN, ZOOM_MAX)
	self.TargetDistance  = self.BaseDistance   -- scroll writes here
	self.CurrentDistance = self.BaseDistance   -- lerps toward TargetDistance

	-- FOV
	self.CurrentFOV = BASE_FOV

	-- Smoothed camera position
	self.SmoothedPos = Camera.CFrame.Position

	-- Seed from character
	local character = LocalPlayer.Character
	local root      = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		self.CameraYaw   = yawFromLook(root.CFrame.LookVector)
		self.FreeLookYaw = self.CameraYaw
		self.SmoothedPos = root.Position + Vector3.new(0, getOffset("heightOffset", DEFAULT_HEIGHT), 0)
	end

	self.RaycastParams            = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	self.Connections = {

		RunService.RenderStepped:Connect(function(dt)
			self:Update(dt)
		end),

		------------------------------------------------------------------------
		-- Keyboard input
		------------------------------------------------------------------------
		InputService.InputBegan:Connect(function(input, gameProcessed)
			-- Only real keyboard events; filters OS-level / mouse / unknown
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			if input.KeyCode.Name == "Unknown" then return end

			local pressedName = input.KeyCode.Name
			if gameProcessed then return end

			local char           = LocalPlayer.Character
			local humanoid       = char and char:FindFirstChildOfClass("Humanoid")
			local shoulderKey    = getKeyName(Shoulder_Switch.Value)
			local freeLookKey    = getKeyName(Free_Look.Value)
			local firstPersonKey = getKeyName(First_Person.Value)

			-- Shoulder swap
			if keyMatches(pressedName, shoulderKey) then
				if self.ShoulderDebounce then return end
				self.ShoulderDebounce = true
				self.IsRightShoulder  = not self.IsRightShoulder
				self.TargetShoulder   = self.IsRightShoulder
				and self.RightShoulderOffset or self.LeftShoulderOffset
				task.delay(SHOULDER_DEBOUNCE, function()
					self.ShoulderDebounce = false
				end)

				-- Free-look toggle — one press on, one press off
			elseif keyMatches(pressedName, freeLookKey) then
				if self.FreeLookDebounce then
					return
				end
				self.FreeLookDebounce = true
				task.delay(FREELOOK_DEBOUNCE, function()
					self.FreeLookDebounce = false
				end)

				self.IsFreeLook = not self.IsFreeLook

				if self.IsFreeLook then
					-- Entering free-look:
					-- Pan phase moves the camera smoothly to the head.
					-- Orbit phase starts immediately after; mouse drives
					-- the camera with no button held — just like shift-lock.
					self.FreeLookPhase = "panning"
					self.FreeLookYaw   = self.CameraYaw
					self.FreeLookPitch = self.CameraPitch
					-- Lock mouse centre so mouse delta works immediately
					-- for when the orbit phase begins
					InputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
					InputService.MouseIconEnabled = false
					if humanoid then humanoid.AutoRotate = true end
				else
					-- Exiting free-look: re-lock to OTS
					self.FreeLookPhase            = "orbiting"
					InputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
					InputService.MouseIconEnabled = false
					if humanoid then humanoid.AutoRotate = false end
					local r = char and char:FindFirstChild("HumanoidRootPart")
					if r then
						self.CameraYaw = yawFromLook(r.CFrame.LookVector)
					end
					self.CameraPitch = 0
				end

				-- First-person toggle
			elseif keyMatches(pressedName, firstPersonKey) then
				if self.FirstPersonDebounce then return end
				self.FirstPersonDebounce = true
				self.IsFirstPerson       = not self.IsFirstPerson
				if self.IsFreeLook then
					self.IsFreeLook               = false
					self.FreeLookPhase            = "orbiting"
					InputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
					InputService.MouseIconEnabled = false
					if humanoid then humanoid.AutoRotate = false end
				end
				self.FreeLookYaw   = self.CameraYaw
				self.FreeLookPitch = self.CameraPitch
				task.delay(FIRST_PERSON_DEBOUNCE, function()
					self.FirstPersonDebounce = false
				end)
			end
		end),

		------------------------------------------------------------------------
		-- Scroll zoom — adjusts OTS distance only (not active in free-look/FP)
		------------------------------------------------------------------------
		InputService.InputChanged:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
			-- Don't zoom in free-look or first-person
			if self.IsFreeLook or self.IsFirstPerson then return end

			-- input.Position.Z is +1 (scroll up = zoom in) or -1 (scroll down = zoom out)
			local direction  = -input.Position.Z   -- invert: scroll up = closer
			self.TargetDistance = math.clamp(
				self.TargetDistance + direction * ZOOM_STEP,
				ZOOM_MIN,
				ZOOM_MAX
			)

		end),

		------------------------------------------------------------------------
		-- Safety: exit free-look on window focus loss (e.g. Alt-Tab)
		InputService.WindowFocusReleased:Connect(function()
			if self.IsFreeLook then

				self.IsFreeLook               = false
				self.FreeLookPhase            = "orbiting"
				InputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
				InputService.MouseIconEnabled = false
				local char = LocalPlayer.Character
				local h    = char and char:FindFirstChildOfClass("Humanoid")
				if h then h.AutoRotate = false end
			end
		end),

		------------------------------------------------------------------------
		LocalPlayer.CharacterAdded:Connect(function(newCharacter)

			self.IsFirstPerson       = false
			self.IsFreeLook          = false
			self.FreeLookPhase       = "orbiting"
			self.FreeLookDebounce    = false
			self.FirstPersonDebounce = false
			self.ShoulderDebounce    = false
			InputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
			InputService.MouseIconEnabled = false
			local r = newCharacter:WaitForChild("HumanoidRootPart")
			self.CameraYaw     = yawFromLook(r.CFrame.LookVector)
			self.CameraPitch   = 0
			self.FreeLookYaw   = self.CameraYaw
			self.FreeLookPitch = 0
			self.SmoothedPos   =
				r.Position + Vector3.new(0, getOffset("heightOffset", DEFAULT_HEIGHT), 0)

		end),
	}


end

------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------

function BaseCamera:Update(dt: number)

	local character = LocalPlayer.Character
	if not character then return end

	local root     = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	self.RaycastParams.FilterDescendantsInstances = {character}

	local heightOffset = getOffset("heightOffset", DEFAULT_HEIGHT)

	--------------------------------------------------------------------
	-- 1. Mouse delta → angles
	-- In free-look (orbiting phase) mouse is locked and drives the orbit.
	-- In OTS mouse is locked and drives the OTS camera + body.
	-- In both cases MouseBehavior is LockCenter so delta is always live.
	--------------------------------------------------------------------

	local delta       = InputService:GetMouseDelta()
	local sensitivity = getOffset("rotationSpeed", 0.25)

	if self.IsFreeLook then
		-- During panning we discard mouse input so the pan plays cleanly.
		-- Once orbiting, mouse drives the free-look angles directly.
		if self.FreeLookPhase == "orbiting" then
			self.FreeLookYaw   += math.rad(-delta.X * sensitivity)
			self.FreeLookPitch += math.rad(-delta.Y * sensitivity)
			self.FreeLookPitch  = math.clamp(self.FreeLookPitch, PITCH_CLAMP_MIN, PITCH_CLAMP_MAX)
		end
		humanoid.AutoRotate = true
	else
		humanoid.AutoRotate = false
		self.CameraYaw   += math.rad(-delta.X * sensitivity)
		self.CameraPitch += math.rad(-delta.Y * sensitivity)
		self.CameraPitch  = math.clamp(self.CameraPitch, PITCH_CLAMP_MIN, PITCH_CLAMP_MAX)
		-- Keep free-look angles in sync so toggling never causes a jump
		self.FreeLookYaw   = self.CameraYaw
		self.FreeLookPitch = self.CameraPitch
	end

	local activeYaw   = self.IsFreeLook and self.FreeLookYaw   or self.CameraYaw
	local activePitch = self.IsFreeLook and self.FreeLookPitch or self.CameraPitch

	--------------------------------------------------------------------
	-- 2. Character body rotation (OTS only)
	--------------------------------------------------------------------

	if not self.IsFreeLook and not self.IsFirstPerson then
		local curYaw = yawFromLook(root.CFrame.LookVector)
		local diff   = math.atan2(
			math.sin(self.CameraYaw - curYaw),
			math.cos(self.CameraYaw - curYaw)
		)
		local turnSpeed = getOffset("characterTurnSpeed", 12)
		local step      = diff * math.clamp(turnSpeed * dt, 0, 1)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, curYaw + step, 0)
	end

	--------------------------------------------------------------------
	-- 3. Shoulder lerp
	--------------------------------------------------------------------

	self.CurrentShoulder = lerp(
		self.CurrentShoulder, self.TargetShoulder, SHOULDER_LERP_SPEED, dt
	)

	--------------------------------------------------------------------
	-- 4. Distance (scroll zoom) & FOV
	-- Sprint temporarily increases distance on top of the scroll offset.
	-- We lerp CurrentDistance toward a composite target each frame.
	--------------------------------------------------------------------

	local speed   = root.AssemblyLinearVelocity.Magnitude
	local moving  = humanoid.MoveDirection.Magnitude > 0.1
	local sprintT = math.clamp(
		(speed - SPRINT_THRESHOLD) / math.max(SPRINT_MAX_SPEED - SPRINT_THRESHOLD, 0.001),
		0, 1
	)

	-- Sprint nudges the distance beyond the scroll target, but never past ZOOM_MAX
	local sprintAdd  = moving and sprintT * SPRINT_DISTANCE_ADD or 0
	local targetDist = math.clamp(self.TargetDistance + sprintAdd, ZOOM_MIN, ZOOM_MAX)
	self.CurrentDistance = lerp(self.CurrentDistance, targetDist, ZOOM_LERP_SPEED, dt)

	local targetFOV = BASE_FOV + (moving and sprintT * (MAX_FOV - BASE_FOV) or 0)
	self.CurrentFOV = lerp(self.CurrentFOV, targetFOV, FOV_SPEED, dt)
	Camera.FieldOfView = self.CurrentFOV

	--------------------------------------------------------------------
	-- 5. First-person mesh visibility
	--------------------------------------------------------------------

	for _, desc in ipairs(character:GetDescendants()) do
		if (desc:IsA("BasePart") or desc:IsA("Decal")) and desc.Name ~= "HumanoidRootPart" then
			desc.LocalTransparencyModifier = self.IsFirstPerson and 1 or 0
		end
	end

	--------------------------------------------------------------------
	-- 6. Rotation CFrame
	--------------------------------------------------------------------

	local rotation =
		CFrame.Angles(0, activeYaw, 0)
		* CFrame.Angles(activePitch, 0, 0)

	local focusPoint = root.Position + Vector3.new(0, heightOffset, 0)

	--------------------------------------------------------------------
	-- 7. Desired camera position
	--------------------------------------------------------------------

	local desiredPos: Vector3

	if self.IsFirstPerson then
		--------------------------------------------------------------------
		-- First-person: camera at head
		--------------------------------------------------------------------
		desiredPos = getHeadPos(character)

	elseif self.IsFreeLook then

		-- Get the head position this frame (tracks the character while orbiting)
		local headPos = getHeadPos(character)

		if self.FreeLookPhase == "panning" then
			--------------------------------------------------------------------
			-- Phase 1 — Pan: lerp SmoothedPos toward head.
			-- We move SmoothedPos directly here; desiredPos is set to SmoothedPos
			-- so the smooth step below is a no-op (we're doing our own lerp).
			-- This avoids the double-lerp that was pushing the camera into the head.
			--------------------------------------------------------------------
			self.SmoothedPos = lerpVec(self.SmoothedPos, headPos, FREELOOK_PAN_SPEED, dt)

			local dist = (self.SmoothedPos - headPos).Magnitude
			if dist < FREELOOK_PAN_THRESHOLD then
				-- Pan complete — snap exactly to head and switch to orbit
				self.SmoothedPos   = headPos
				self.FreeLookPhase = "orbiting"
				self.FreeLookYaw   = activeYaw
				self.FreeLookPitch = activePitch

			end

			-- Set Camera directly and return — skip collision + smooth steps
			Camera.CFrame =
				CFrame.new(self.SmoothedPos)
				* CFrame.Angles(0, activeYaw, 0)
				* CFrame.Angles(activePitch, 0, 0)
			return

		else
			--------------------------------------------------------------------
			-- Phase 2 — Orbit: camera sits FREELOOK_ORBIT_DISTANCE studs behind
			-- the head. Head is centred on screen. Mouse drives yaw/pitch freely.
			--------------------------------------------------------------------
			desiredPos = headPos - rotation.LookVector * FREELOOK_ORBIT_DISTANCE
		end

	else
		--------------------------------------------------------------------
		-- Standard OTS
		--------------------------------------------------------------------
		desiredPos =
			focusPoint
			+ rotation.RightVector * self.CurrentShoulder
		- rotation.LookVector  * self.CurrentDistance
	end

	--------------------------------------------------------------------
	-- 8. Collision
	-- Cast from focusPoint in OTS, from headPos in free-look orbit.
	--------------------------------------------------------------------

	local finalPos  = desiredPos
	local rayOrigin = focusPoint

	if self.IsFreeLook and self.FreeLookPhase == "orbiting" then
		rayOrigin = getHeadPos(character)
	end

	if not self.IsFirstPerson then
		local ray = Workspace:Raycast(rayOrigin, desiredPos - rayOrigin, self.RaycastParams)
		if ray then
			finalPos = ray.Position + ray.Normal * COLLISION_OFFSET
		end
	end

	--------------------------------------------------------------------
	-- 9. Smooth position + apply CFrame
	--------------------------------------------------------------------

	self.SmoothedPos = lerpVec(self.SmoothedPos, finalPos, CAM_SMOOTH_SPEED, dt)

	Camera.CFrame =
		CFrame.new(self.SmoothedPos)
		* CFrame.Angles(0, activeYaw, 0)
		* CFrame.Angles(activePitch, 0, 0)

end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------



local myCameraInfo = {
	name        = "BasicCamera",
	priority    = 1,
	Connections = {},
}

local myCamera = BaseCamera.new(myCameraInfo)
myCamera:Start()



return myCamera