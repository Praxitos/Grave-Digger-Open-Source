--!strict

-- // Services
local InputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- // References
local CameraClass = require(script.Parent.Parent.Parent.Parent.Library.Classes.CameraClass)

-- // Constants
local CAMERA_SMOOTH_SPEED = 12
local SHOULDER_SMOOTH_SPEED = 12
local DISTANCE_SMOOTH_SPEED = 4
local FOV_INCREASE_SPEED = 3
local FOV_DECREASE_SPEED = 1.5

local PITCH_CLAMP_MIN = math.rad(-70)
local PITCH_CLAMP_MAX = math.rad(70)

local HEAD_PITCH_CLAMP_MIN = math.rad(-40)
local HEAD_PITCH_CLAMP_MAX = math.rad(40)
local HEAD_PITCH_MULTIPLIER = 0.6

local SPRINT_THRESHOLD = 17
local SPRINT_MAX_SPEED = 24

local COLLISION_OFFSET = 0.3
local FREE_LOOK_DISTANCE_MULTIPLIER = 2
local FIRST_PERSON_DEBOUNCE = 0.2
local SHOULDER_DEBOUNCE = 0.2

-- Free look camera offsets — tweak these to taste
local FREE_LOOK_EXTRA_DISTANCE = 3    -- how much further back vs normal
local FREE_LOOK_HEIGHT_REDUCTION = 1  -- how much lower the focus point sits

-- // Local Variables
local BaseCamera = setmetatable({}, {__index = CameraClass})
local LocalPlayer = PlayerService.LocalPlayer
local Camera = Workspace.CurrentCamera

local OffsetFolder =
	ReplicatedStorage.Shared.Library.Configuration.Character_Variables.Camera.BaseCamera

local PlayerData = LocalPlayer:WaitForChild("PlayerData")
local SettingsData = PlayerData:WaitForChild("Settings Data")
local InputOptions = SettingsData:WaitForChild("Input Options")

local Shoulder_Switch = InputOptions:WaitForChild("Shoulder Switch")
local Free_Look = InputOptions:WaitForChild("Free Look")
local First_Person = InputOptions:WaitForChild("First Person")

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function getOffset(name: string, default: number): number
	local inst = OffsetFolder:FindFirstChild(name)
	if inst and inst:IsA("NumberValue") then
		return inst.Value
	end
	return default
end

local function smooth(current: number, target: number, speed: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-speed * dt))
end

local function smoothVec(current: Vector3, target: Vector3, speed: number, dt: number): Vector3
	local t = 1 - math.exp(-speed * dt)
	return current:Lerp(target, t)
end

local function getKeyName(value: string): string
	return value:gsub("Enum.KeyCode.", "")
end

-- Fix: correct atan2 order for Roblox -Z forward convention
local function yawFromLook(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

--------------------------------------------------
-- Constructor
--------------------------------------------------

function BaseCamera.new(cameraInfo)
	local self = CameraClass.new(cameraInfo)
	setmetatable(self, {__index = BaseCamera})

	self.CameraPosition = Camera.CFrame.Position
	self.CameraCFrame = Camera.CFrame

	return self
end

--------------------------------------------------
-- Start Camera
--------------------------------------------------

function BaseCamera:Start()

	Camera.CameraType = Enum.CameraType.Scriptable
	LocalPlayer.CameraMode = Enum.CameraMode.Classic

	InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	InputService.MouseIconEnabled = false

	self.CameraYaw = 0
	self.CameraPitch = 0

	-- Free look stores its own separate yaw/pitch so that
	-- when the key is released we can cleanly restore to
	-- the character-aligned camera yaw without a snap.
	self.FreeLookYaw = 0
	self.FreeLookPitch = 0

	self.IsFreeLook = false
	self.IsFirstPerson = false
	self.FirstPersonDebounce = false
	self.ShoulderDebounce = false
	self.IsRightClickOrbit = false  -- true while RMB held during free look

	self.RightShoulderOffset = getOffset("sideOffset", 3)
	self.LeftShoulderOffset = -getOffset("sideOffset", 3)

	self.IsRightShoulder = true
	self.TargetShoulder = self.RightShoulderOffset
	self.CurrentShoulder = self.TargetShoulder

	self.BaseDistance = getOffset("distanceBehind", 6)
	self.SprintDistance = getOffset("distanceSprint", 8)

	self.CurrentDistance = self.BaseDistance
	self.TargetDistance = self.BaseDistance

	self.BaseFOV = 70
	self.MaxFOV = 80
	self.CurrentFOV = self.BaseFOV

	-- Seed yaw from current character facing so the camera
	-- doesn't snap on first frame.
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		self.CameraYaw = yawFromLook(root.CFrame.LookVector)
		self.FreeLookYaw = self.CameraYaw
	end

	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	self.Connections = {

		RunService.RenderStepped:Connect(function(dt)
			self:Update(dt)
		end),

		InputService.InputBegan:Connect(function(input, gameProcessed)

			if gameProcessed then return end

			local shoulderKey    = getKeyName(Shoulder_Switch.Value)
			local freeLookKey    = getKeyName(Free_Look.Value)
			local firstPersonKey = getKeyName(First_Person.Value)

			if input.KeyCode.Name == shoulderKey then

				if self.ShoulderDebounce then return end
				self.ShoulderDebounce = true

				self.IsRightShoulder = not self.IsRightShoulder
				self.TargetShoulder =
					self.IsRightShoulder and self.RightShoulderOffset or self.LeftShoulderOffset

				task.delay(SHOULDER_DEBOUNCE, function()
					self.ShoulderDebounce = false
				end)

			elseif input.KeyCode.Name == freeLookKey then

				-- Seed free-look angles from the current camera so
				-- there's no jump when the key is first pressed.
				self.FreeLookYaw   = self.CameraYaw
				self.FreeLookPitch = self.CameraPitch
				self.IsFreeLook    = true

				-- Unlock mouse so the player can look around freely
				InputService.MouseBehavior = Enum.MouseBehavior.Default
				InputService.MouseIconEnabled = true

			elseif input.KeyCode.Name == firstPersonKey then

				-- Debounce: ignore rapid re-presses
				if self.FirstPersonDebounce then return end
				self.FirstPersonDebounce = true

				self.IsFirstPerson = not self.IsFirstPerson
				self.IsFreeLook    = false

				-- Re-lock mouse in case free look was active
				InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				InputService.MouseIconEnabled = false

				-- Re-align free look state with main yaw when toggling
				-- first person so there's no drift.
				self.FreeLookYaw   = self.CameraYaw
				self.FreeLookPitch = self.CameraPitch

				task.delay(FIRST_PERSON_DEBOUNCE, function()
					self.FirstPersonDebounce = false
				end)

			end

			-- RMB orbit: only active while in free look
			if input.UserInputType == Enum.UserInputType.MouseButton2 and self.IsFreeLook then
				self.IsRightClickOrbit = true
				InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			end

		end),

		InputService.InputEnded:Connect(function(input, gameProcessed)

			if gameProcessed then return end

			local freeLookKey = getKeyName(Free_Look.Value)

			if input.KeyCode.Name == freeLookKey then

				self.IsFreeLook        = false
				self.IsRightClickOrbit = false

				-- Re-lock the mouse now that free look is done
				InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				InputService.MouseIconEnabled = false

				-- Snap main camera yaw back to the character's actual
				-- facing direction so there's no lurch on release.
				local char = LocalPlayer.Character
				local r    = char and char:FindFirstChild("HumanoidRootPart")
				if r then
					self.CameraYaw = yawFromLook(r.CFrame.LookVector)
				end
				self.CameraPitch = 0

			end

			-- RMB released: restore free cursor
			if input.UserInputType == Enum.UserInputType.MouseButton2 and self.IsFreeLook then
				self.IsRightClickOrbit = false
				InputService.MouseBehavior = Enum.MouseBehavior.Default
			end

		end),

		LocalPlayer.CharacterAdded:Connect(function(newCharacter)

			self.IsFirstPerson       = false
			self.IsFreeLook          = false
			self.FirstPersonDebounce = false
			self.ShoulderDebounce    = false
			self.IsRightClickOrbit   = false

			-- Always re-lock mouse on respawn
			InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			InputService.MouseIconEnabled = false

			local r = newCharacter:WaitForChild("HumanoidRootPart")

			self.CameraYaw    = yawFromLook(r.CFrame.LookVector)
			self.CameraPitch  = 0
			self.FreeLookYaw  = self.CameraYaw
			self.FreeLookPitch = 0

		end),
	}
end

--------------------------------------------------
-- Update
--------------------------------------------------

function BaseCamera:Update(dt)

	local character = LocalPlayer.Character
	if not character then return end

	local root      = character:FindFirstChild("HumanoidRootPart")
	local humanoid  = character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid then return end

	humanoid.AutoRotate = false

	self.RaycastParams.FilterDescendantsInstances = {character}

	--------------------------------------------------
	-- Mouse input — split between free-look and normal
	--------------------------------------------------

	local mouseDelta = InputService:GetMouseDelta()
	local sensitivity = getOffset("rotationSpeed", 0.25)

	if self.IsFreeLook then
		-- Free look: only move the free-look angles, leave
		-- CameraYaw / CameraPitch (and therefore the character) alone.
		-- RMB held: mouse is locked so delta drives the orbit spin.
		-- RMB not held: mouse is free-floating so delta is always zero —
		-- the player just moves their cursor without spinning the camera.
		if self.IsRightClickOrbit then
			self.FreeLookYaw   += math.rad(-mouseDelta.X * sensitivity)
			self.FreeLookPitch += math.rad(-mouseDelta.Y * sensitivity)
			self.FreeLookPitch  = math.clamp(self.FreeLookPitch, PITCH_CLAMP_MIN, PITCH_CLAMP_MAX)
		end
		-- When not right-clicking we intentionally do nothing with mouseDelta
		-- so the camera stays frozen while the cursor roams freely.
	else
		-- Normal: drive the main camera angles.
		self.CameraYaw   += math.rad(-mouseDelta.X * sensitivity)
		self.CameraPitch += math.rad(-mouseDelta.Y * sensitivity)
		self.CameraPitch  = math.clamp(self.CameraPitch, PITCH_CLAMP_MIN, PITCH_CLAMP_MAX)

		-- Keep free-look in sync so it doesn't jump when first pressed.
		self.FreeLookYaw   = self.CameraYaw
		self.FreeLookPitch = self.CameraPitch
	end

	-- Which angles drive the camera this frame
	local activeYaw   = self.IsFreeLook and self.FreeLookYaw   or self.CameraYaw
	local activePitch = self.IsFreeLook and self.FreeLookPitch or self.CameraPitch

	--------------------------------------------------
	-- Smooth shoulder / distance
	--------------------------------------------------

	self.CurrentShoulder = smooth(
		self.CurrentShoulder,
		self.TargetShoulder,
		SHOULDER_SMOOTH_SPEED,
		dt
	)

	self.CurrentDistance = smooth(
		self.CurrentDistance,
		self.TargetDistance,
		DISTANCE_SMOOTH_SPEED,
		dt
	)

	--------------------------------------------------
	-- Rotate Character (OVER-THE-SHOULDER)
	-- Skipped during free-look so the body stays still,
	-- and skipped in first person (body faces camera directly).
	--------------------------------------------------

	if not self.IsFreeLook then

		local currentLook = root.CFrame.LookVector
		local currentYaw  = yawFromLook(currentLook)

		local deltaYaw = math.atan2(
			math.sin(self.CameraYaw - currentYaw),
			math.cos(self.CameraYaw - currentYaw)
		)

		local turnSpeed = getOffset("characterTurnSpeed", 12)
		local step      = deltaYaw * math.clamp(turnSpeed * dt, 0, 1)

		root.CFrame =
			CFrame.new(root.Position)
			* CFrame.Angles(0, currentYaw + step, 0)

	end

	--------------------------------------------------
	-- First-person: hide / show character meshes.
	--------------------------------------------------

	-- Hide body parts in first person so the mesh doesn't clip the camera.
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") or desc:IsA("Decal") then
			if desc.Name ~= "HumanoidRootPart" then
				desc.LocalTransparencyModifier = self.IsFirstPerson and 1 or 0
			end
		end
	end

	--------------------------------------------------
	-- Camera positioning
	--------------------------------------------------

	local rotation =
		CFrame.Angles(0, activeYaw, 0)
		* CFrame.Angles(activePitch, 0, 0)

	local heightOffset = getOffset("heightOffset", 2)
	local focusPoint   = root.Position + Vector3.new(0, heightOffset, 0)

	local desiredPos

	if self.IsFirstPerson then
		-- Place camera at the head position directly
		local head = character:FindFirstChild("Head")
		local headPos = head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
		desiredPos = headPos
	elseif self.IsFreeLook then
		-- Free look: orbit around the centre of the player, pulled back
		-- further and sitting slightly lower than normal OTS.
		local freeLookFocus =
			root.Position + Vector3.new(0, heightOffset - FREE_LOOK_HEIGHT_REDUCTION, 0)
		desiredPos =
			freeLookFocus
			- rotation.LookVector * (self.CurrentDistance + FREE_LOOK_EXTRA_DISTANCE)
	else
		desiredPos =
			focusPoint
			+ rotation.RightVector * self.CurrentShoulder
			- rotation.LookVector  * self.CurrentDistance
	end

	-- Collision check: only cast when not in first person
	local finalPos = desiredPos

	if not self.IsFirstPerson then
		local origin    = self.IsFreeLook
			and (root.Position + Vector3.new(0, heightOffset - FREE_LOOK_HEIGHT_REDUCTION, 0))
			or  focusPoint
		local direction = desiredPos - origin
		local ray       = Workspace:Raycast(origin, direction, self.RaycastParams)
		if ray then
			finalPos = ray.Position + ray.Normal * COLLISION_OFFSET
		end
	end

	-- Smooth the camera position with a proper Vector3 lerp
	self.CameraPosition = smoothVec(
		self.CameraPosition or finalPos,
		finalPos,
		CAMERA_SMOOTH_SPEED,
		dt
	)

	Camera.CFrame =
		CFrame.new(self.CameraPosition)
		* rotation

	--------------------------------------------------
	-- FOV
	--------------------------------------------------

	local targetFOV = self.BaseFOV

	if humanoid.MoveDirection.Magnitude > 0.1 then
		local speed     = root.AssemblyLinearVelocity.Magnitude
		local sprintT   = math.clamp((speed - SPRINT_THRESHOLD) / (SPRINT_MAX_SPEED - SPRINT_THRESHOLD), 0, 1)
		targetFOV       = self.BaseFOV + (self.MaxFOV - self.BaseFOV) * sprintT
	end

	local fovSpeed = targetFOV > self.CurrentFOV and FOV_INCREASE_SPEED or FOV_DECREASE_SPEED
	self.CurrentFOV = smooth(self.CurrentFOV, targetFOV, fovSpeed, dt)
	Camera.FieldOfView = self.CurrentFOV

end

--------------------------------------------------
-- Init
--------------------------------------------------

local myCameraInfo = {
	name       = "BasicCamera",
	priority   = 1,
	Connections = {},
}

local myCamera = BaseCamera.new(myCameraInfo)

myCamera:Start()

return myCamera