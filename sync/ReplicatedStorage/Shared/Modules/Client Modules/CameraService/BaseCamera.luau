--!strict

------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------

local InputService      = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local PlayerService     = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local CameraClass = require(script.Parent.Parent.Parent.Parent.Library.Classes.Miscellanous.CameraClass)

------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------

local PITCH_MIN = math.rad(-70)
local PITCH_MAX = math.rad(70)

local CAM_SMOOTH_SPEED    = 20

local DEFAULT_DISTANCE    = 5
local DEFAULT_SIDE        = 1.8
local DEFAULT_HEIGHT      = 1.6
local SHOULDER_LERP_SPEED = 14

local SPRINT_DISTANCE_ADD = 1.2
local SPRINT_THRESHOLD    = 17
local SPRINT_MAX_SPEED    = 24

local BASE_FOV  = 70
local MAX_FOV   = 80
local FOV_SPEED = 4

local ZOOM_MIN        = 2
local ZOOM_MAX        = 6
local ZOOM_STEP       = 0.6
local ZOOM_LERP_SPEED = 10

local COLLISION_OFFSET = 0.25

local FREELOOK_PAN_SPEED      = 8
local FREELOOK_PAN_THRESHOLD  = 0.25
local FREELOOK_ORBIT_DISTANCE = 5

local FIRST_PERSON_DEBOUNCE = 0.2
local SHOULDER_DEBOUNCE     = 0.2
local FREELOOK_DEBOUNCE     = 0.15

local RECOIL_DECAY_SPEED = 8

------------------------------------------------------------------------
-- Module setup
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
	return (inst and inst:IsA("NumberValue")) and inst.Value or default
end

local function getKeyName(value: string): string
	return value:gsub("Enum.KeyCode.", "")
end

local function keyMatches(pressed: string, binding: string): boolean
	if pressed == binding then return true end
	local alts = { Alt = true, LeftAlt = true, RightAlt = true }
	return alts[pressed] and alts[binding] or false
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

local function getHeadPos(character: Model): Vector3
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head.Position end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position + Vector3.new(0, 1.5, 0)) or Vector3.zero
end

local function exitFreeLook(self, char)
	self.IsFreeLook               = false
	self.FreeLookPhase            = "orbiting"
	InputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
	InputService.MouseIconEnabled = false
	local h = char and char:FindFirstChildOfClass("Humanoid")
	if h then h.AutoRotate = false end
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

	LocalPlayer:SetAttribute("Current_Shoulder", "Right")

	self.CameraYaw   = 0
	self.CameraPitch = 0

	self.IsFreeLook       = false
	self.FreeLookPhase    = "orbiting"
	self.FreeLookYaw      = 0
	self.FreeLookPitch    = 0
	self.FreeLookDebounce = false
	self.FreeLookRMB      = false

	self.IsFirstPerson       = false
	self.FirstPersonDebounce = false

	self.RightShoulderOffset = getOffset("sideOffset", DEFAULT_SIDE)
	self.LeftShoulderOffset  = -getOffset("sideOffset", DEFAULT_SIDE)
	self.IsRightShoulder     = true
	self.TargetShoulder      = self.RightShoulderOffset
	self.CurrentShoulder     = self.TargetShoulder
	self.ShoulderDebounce    = false

	self.BaseDistance    = math.clamp(getOffset("distanceBehind", DEFAULT_DISTANCE), ZOOM_MIN, ZOOM_MAX)
	self.TargetDistance  = self.BaseDistance
	self.CurrentDistance = self.BaseDistance

	self.CurrentFOV  = BASE_FOV
	self.SmoothedPos = Camera.CFrame.Position

	-- Recoil state
	self.RecoilPitch = 0
	self.RecoilYaw   = 0

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
			if gameProcessed then return end

			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				if self.IsFreeLook and self.FreeLookPhase == "orbiting" then
					self.FreeLookRMB = true
				end
				return
			end

			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			if input.KeyCode.Name == "Unknown" then return end

			local pressedName    = input.KeyCode.Name
			local char           = LocalPlayer.Character
			local humanoid       = char and char:FindFirstChildOfClass("Humanoid")
			local shoulderKey    = getKeyName(Shoulder_Switch.Value)
			local freeLookKey    = getKeyName(Free_Look.Value)
			local firstPersonKey = getKeyName(First_Person.Value)

			if keyMatches(pressedName, shoulderKey) then
				if self.ShoulderDebounce then return end
				self.ShoulderDebounce = true
				self.IsRightShoulder  = not self.IsRightShoulder
				self.TargetShoulder   = self.IsRightShoulder
					and self.RightShoulderOffset or self.LeftShoulderOffset
				
				if LocalPlayer:GetAttribute("Current_Shoulder") == "Right" then
					LocalPlayer:SetAttribute("Current_Shoulder", "Left")
				else
					LocalPlayer:SetAttribute("Current_Shoulder", "Right")
				end
				
				task.delay(SHOULDER_DEBOUNCE, function() self.ShoulderDebounce = false end)

			elseif keyMatches(pressedName, freeLookKey) then
				if self.FreeLookDebounce then return end
				self.FreeLookDebounce = true
				task.delay(FREELOOK_DEBOUNCE, function() self.FreeLookDebounce = false end)

				self.IsFreeLook = not self.IsFreeLook

				if self.IsFreeLook then
					self.FreeLookPhase            = "panning"
					self.FreeLookYaw              = self.CameraYaw
					self.FreeLookPitch            = self.CameraPitch
					InputService.MouseBehavior    = Enum.MouseBehavior.Default
					InputService.MouseIconEnabled = true
					if humanoid then humanoid.AutoRotate = true end
				else
					exitFreeLook(self, char)
					local r = char and char:FindFirstChild("HumanoidRootPart")
					if r then self.CameraYaw = yawFromLook(r.CFrame.LookVector) end
					self.CameraPitch = 0
				end

			elseif keyMatches(pressedName, firstPersonKey) then
				if self.FirstPersonDebounce then return end
				self.FirstPersonDebounce = true
				self.IsFirstPerson = not self.IsFirstPerson
				if self.IsFreeLook then exitFreeLook(self, char) end
				self.FreeLookYaw   = self.CameraYaw
				self.FreeLookPitch = self.CameraPitch
				task.delay(FIRST_PERSON_DEBOUNCE, function() self.FirstPersonDebounce = false end)
			end
		end),

		------------------------------------------------------------------------
		-- RMB released
		------------------------------------------------------------------------
		InputService.InputEnded:Connect(function(input, gameProcessed)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				if self.FreeLookRMB then
					self.FreeLookRMB              = false
					InputService.MouseBehavior    = Enum.MouseBehavior.LockCenter
					InputService.MouseIconEnabled = false
				end
			end
		end),

		------------------------------------------------------------------------
		-- Scroll zoom
		------------------------------------------------------------------------
		InputService.InputChanged:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
			if self.IsFreeLook or self.IsFirstPerson then return end

			local direction = -input.Position.Z
			self.TargetDistance = math.clamp(
				self.TargetDistance + direction * ZOOM_STEP,
				ZOOM_MIN, ZOOM_MAX
			)
		end),

		------------------------------------------------------------------------
		-- Focus lost
		------------------------------------------------------------------------
		InputService.WindowFocusReleased:Connect(function()
			if self.IsFreeLook then
				exitFreeLook(self, LocalPlayer.Character)
			end
		end),

		------------------------------------------------------------------------
		-- Character respawn
		------------------------------------------------------------------------
		LocalPlayer.CharacterAdded:Connect(function(newCharacter)
			self.IsFirstPerson       = false
			self.FreeLookRMB         = false
			self.FreeLookDebounce    = false
			self.FirstPersonDebounce = false
			self.ShoulderDebounce    = false
			self.RecoilPitch         = 0
			self.RecoilYaw           = 0
			exitFreeLook(self, newCharacter)

			local r = newCharacter:WaitForChild("HumanoidRootPart")
			self.CameraYaw     = yawFromLook(r.CFrame.LookVector)
			self.CameraPitch   = 0
			self.FreeLookYaw   = self.CameraYaw
			self.FreeLookPitch = 0
			self.SmoothedPos   = r.Position + Vector3.new(0, getOffset("heightOffset", DEFAULT_HEIGHT), 0)
		end),
	}
end

------------------------------------------------------------------------
-- ApplyRecoil
------------------------------------------------------------------------

function BaseCamera:ApplyRecoil(pitchDelta: number, yawDelta: number)
	self.RecoilPitch += pitchDelta
	self.RecoilYaw   += yawDelta
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
	local sensitivity  = getOffset("rotationSpeed", 0.25)
	local delta        = InputService:GetMouseDelta()

	--------------------------------------------------------------------
	-- 1. Mouse delta → angles
	--------------------------------------------------------------------

	if self.IsFreeLook then
		humanoid.AutoRotate = true
		if self.FreeLookPhase == "orbiting" then
			self.FreeLookYaw   += math.rad(-delta.X * sensitivity)
			self.FreeLookPitch += math.rad(-delta.Y * sensitivity)
			self.FreeLookPitch  = math.clamp(self.FreeLookPitch, PITCH_MIN, PITCH_MAX)
		end
	else
		humanoid.AutoRotate = false
		self.CameraYaw   += math.rad(-delta.X * sensitivity)
		self.CameraPitch += math.rad(-delta.Y * sensitivity)
		self.CameraPitch  = math.clamp(self.CameraPitch, PITCH_MIN, PITCH_MAX)
		self.FreeLookYaw   = self.CameraYaw
		self.FreeLookPitch = self.CameraPitch
	end

	-- Decay recoil
	self.RecoilPitch = lerp(self.RecoilPitch, 0, RECOIL_DECAY_SPEED, dt)
	self.RecoilYaw   = lerp(self.RecoilYaw,   0, RECOIL_DECAY_SPEED, dt)

	local activeYaw   = (self.IsFreeLook and self.FreeLookYaw   or self.CameraYaw)   + self.RecoilYaw
	local activePitch = (self.IsFreeLook and self.FreeLookPitch or self.CameraPitch) + self.RecoilPitch

	--------------------------------------------------------------------
	-- 2. Character body rotation (OTS only)
	--------------------------------------------------------------------

	if not self.IsFreeLook and not self.IsFirstPerson then
		local curYaw    = yawFromLook(root.CFrame.LookVector)
		local diff      = math.atan2(math.sin(self.CameraYaw - curYaw), math.cos(self.CameraYaw - curYaw))
		local turnSpeed = getOffset("characterTurnSpeed", 12)
		root.CFrame     = CFrame.new(root.Position) * CFrame.Angles(0, curYaw + diff * math.clamp(turnSpeed * dt, 0, 1), 0)
	end

	--------------------------------------------------------------------
	-- 3. Shoulder lerp
	--------------------------------------------------------------------

	self.CurrentShoulder = lerp(self.CurrentShoulder, self.TargetShoulder, SHOULDER_LERP_SPEED, dt)

	--------------------------------------------------------------------
	-- 4. Distance & FOV
	--------------------------------------------------------------------

	local speed   = root.AssemblyLinearVelocity.Magnitude
	local moving  = humanoid.MoveDirection.Magnitude > 0.1
	local sprintT = math.clamp(
		(speed - SPRINT_THRESHOLD) / math.max(SPRINT_MAX_SPEED - SPRINT_THRESHOLD, 0.001),
		0, 1
	)

	local sprintAdd = moving and sprintT * SPRINT_DISTANCE_ADD or 0
	self.CurrentDistance = lerp(
		self.CurrentDistance,
		math.clamp(self.TargetDistance + sprintAdd, ZOOM_MIN, ZOOM_MAX),
		ZOOM_LERP_SPEED, dt
	)

	self.CurrentFOV    = lerp(self.CurrentFOV, BASE_FOV + (moving and sprintT * (MAX_FOV - BASE_FOV) or 0), FOV_SPEED, dt)
	--Camera.FieldOfView = self.CurrentFOV

	--------------------------------------------------------------------
	-- 5. First-person mesh visibility
	--------------------------------------------------------------------

	for _, desc in ipairs(character:GetDescendants()) do
		if (desc:IsA("BasePart") or desc:IsA("Decal")) and desc.Name ~= "HumanoidRootPart" then
			desc.LocalTransparencyModifier = self.IsFirstPerson and 1 or 0
		end
	end

	--------------------------------------------------------------------
	-- 6. Rotation CFrame + focus point
	--------------------------------------------------------------------

	local rotation   = CFrame.Angles(0, activeYaw, 0) * CFrame.Angles(activePitch, 0, 0)
	local focusPoint = root.Position + Vector3.new(0, heightOffset, 0)
	local headPos    = getHeadPos(character)

	--------------------------------------------------------------------
	-- 7. Desired camera position
	--------------------------------------------------------------------

	local desiredPos: Vector3
	local rayOrigin:  Vector3

	if self.IsFirstPerson then
		desiredPos = headPos
		rayOrigin  = headPos

	elseif self.IsFreeLook then

		if self.FreeLookPhase == "panning" then
			local orbitPos = headPos - rotation.LookVector * FREELOOK_ORBIT_DISTANCE
			self.SmoothedPos = lerpVec(self.SmoothedPos, orbitPos, FREELOOK_PAN_SPEED, dt)

			if (self.SmoothedPos - orbitPos).Magnitude < FREELOOK_PAN_THRESHOLD then
				self.SmoothedPos   = orbitPos
				self.FreeLookPhase = "orbiting"
				self.FreeLookYaw   = activeYaw
				self.FreeLookPitch = activePitch
			end

			Camera.CFrame = CFrame.new(self.SmoothedPos) * CFrame.Angles(0, activeYaw, 0) * CFrame.Angles(activePitch, 0, 0)
			return
		end

		desiredPos = headPos - rotation.LookVector * FREELOOK_ORBIT_DISTANCE
		rayOrigin  = headPos

	else
		desiredPos = focusPoint + rotation.RightVector * self.CurrentShoulder - rotation.LookVector * self.CurrentDistance
		rayOrigin  = focusPoint
	end

	--------------------------------------------------------------------
	-- 8. Collision
	--------------------------------------------------------------------

	local finalPos = desiredPos

	if not self.IsFirstPerson then
		local ray = Workspace:Raycast(rayOrigin, desiredPos - rayOrigin, self.RaycastParams)
		if ray then
			finalPos = ray.Position + ray.Normal * COLLISION_OFFSET
		end
	end

	--------------------------------------------------------------------
	-- 9. Smooth + apply
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

local myCamera = BaseCamera.new({ name = "BasicCamera", priority = 1, Connections = {} })
myCamera:Start()

return myCamera