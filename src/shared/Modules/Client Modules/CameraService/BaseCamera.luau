--!strict

-- // Services
local InputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- // References
local CameraClass = require(script.Parent.Parent.Parent.Parent.Library.Classes.CameraClass)
local Types = require(script.Parent.Parent.Parent.Parent.Library.Types.MainTypes)

-- // Constants
local CAMERA_SMOOTH_SPEED = 12
local SHOULDER_SMOOTH_SPEED = 12
local DISTANCE_SMOOTH_SPEED = 4
local FOV_INCREASE_SPEED = 3
local FOV_DECREASE_SPEED = 1.5
local TOGGLE_DEBOUNCE_TIME = 0.1
local PITCH_CLAMP_MIN = math.rad(-70)
local PITCH_CLAMP_MAX = math.rad(70)
local HEAD_PITCH_CLAMP_MIN = math.rad(-40)
local HEAD_PITCH_CLAMP_MAX = math.rad(40)
local HEAD_PITCH_MULTIPLIER = 0.6
local SPRINT_THRESHOLD = 17
local SPRINT_MAX_SPEED = 26
local COLLISION_OFFSET = 0.3
local FREE_LOOK_DISTANCE_MULTIPLIER = 2
local FREE_LOOK_HEIGHT_OFFSET = 3

-- // Local Variables
local BaseCamera = setmetatable({}, { __index = CameraClass })
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

-- // Helper Functions
local function getOffset(name: string, default: number): number
	local inst = OffsetFolder:FindFirstChild(name)
	if inst and inst:IsA("NumberValue") then
		return inst.Value
	end
	return default
end

local function smooth(current: number, target: number, speed: number, dt: number): number
	local alpha = 1 - math.exp(-speed * dt)
	return current + (target - current) * alpha
end

local function getKeyName(value: string): string
	return value:gsub("Enum.KeyCode.", "")
end

-- Hides/restores head mesh and all accessories using LocalTransparencyModifier
-- so it only affects the local player's view, not other players.
local function setFirstPersonVisibility(character: Model, hidden: boolean)
	-- Head part
	local head = character:FindFirstChild("Head") :: BasePart?
	if head then
		if hidden then
			head:SetAttribute("FP_OrigLocalTrans", head.LocalTransparencyModifier)
			head.LocalTransparencyModifier = 1
		else
			local orig = head:GetAttribute("FP_OrigLocalTrans")
			head.LocalTransparencyModifier = if orig ~= nil then (orig :: number) else 0
		end

		-- Decals on the head (face texture etc.) — SpecialMesh has no Transparency, skip it
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("Decal") then
				local decal = child :: Decal
				if hidden then
					decal:SetAttribute("FP_OrigTrans", decal.Transparency)
					decal.Transparency = 1
				else
					local orig = decal:GetAttribute("FP_OrigTrans")
					decal.Transparency = if orig ~= nil then (orig :: number) else 0
				end
			end
		end
	end

	-- All accessories (hats, hair, face accessories, etc.)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle") :: BasePart?
			if handle then
				if hidden then
					handle:SetAttribute("FP_OrigLocalTrans", handle.LocalTransparencyModifier)
					handle.LocalTransparencyModifier = 1
				else
					local orig = handle:GetAttribute("FP_OrigLocalTrans")
					handle.LocalTransparencyModifier = if orig ~= nil then (orig :: number) else 0
				end
			end
		end
	end
end

-- // Class Constructor
function BaseCamera.new(cameraInfo: Types.Camera_Type)
	local self = CameraClass.new(cameraInfo)
	setmetatable(self, { __index = BaseCamera })

	self.CameraCFrame = Camera.CFrame
	return self
end

-- // Start Camera
function BaseCamera:Start()
	Camera.CameraType = Enum.CameraType.Scriptable
	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	InputService.MouseIconEnabled = false

	self.CameraYaw = 0
	self.CameraPitch = 0

	self.RightShoulderOffset = getOffset("sideOffset", 3)
	self.LeftShoulderOffset = -getOffset("sideOffset", 3)

	self.IsRightShoulder = true
	self.TargetShoulder = self.RightShoulderOffset
	self.CurrentShoulder = self.TargetShoulder
	self.LastToggleTime = 0

	self.IsFreeLook = false
	self.IsFirstPerson = false

	self.BaseDistance = getOffset("distanceBehind", 6)
	self.SprintDistance = getOffset("distanceSprint", 8)

	self.CurrentDistance = self.BaseDistance
	self.TargetDistance = self.BaseDistance

	self.BaseFOV = 70
	self.MaxFOV = 73
	self.CurrentFOV = self.BaseFOV

	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root then
		local look = root.CFrame.LookVector
		self.CameraYaw = math.atan2(look.X, look.Z)
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
				if tick() - self.LastToggleTime < TOGGLE_DEBOUNCE_TIME then return end
				self.LastToggleTime = tick()
				self.IsRightShoulder = not self.IsRightShoulder
				self.TargetShoulder = self.IsRightShoulder and self.RightShoulderOffset or self.LeftShoulderOffset

			elseif input.KeyCode.Name == freeLookKey then
				self.IsFreeLook = true
				if not InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
					InputService.MouseBehavior = Enum.MouseBehavior.Default
					InputService.MouseIconEnabled = true
				end

			elseif input.KeyCode.Name == firstPersonKey then
				if tick() - self.LastToggleTime < TOGGLE_DEBOUNCE_TIME then return end
				self.LastToggleTime = tick()

				self.IsFirstPerson = not self.IsFirstPerson
				self.IsFreeLook = false

				local ch = LocalPlayer.Character
				if ch then
					if self.IsFirstPerson then
						-- Snap yaw to root so camera doesn't jump sideways on entry
						local r = ch:FindFirstChild("HumanoidRootPart")
						if r then
							local _, yaw, _ = r.CFrame:ToOrientation()
							self.CameraYaw = yaw
						end
						setFirstPersonVisibility(ch, true)
					else
						setFirstPersonVisibility(ch, false)
					end
				end

				InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				InputService.MouseIconEnabled = false
			end
		end),

		InputService.InputEnded:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			local freeLookKey = getKeyName(Free_Look.Value)
			if input.KeyCode.Name == freeLookKey then
				self.IsFreeLook = false
				InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				InputService.MouseIconEnabled = false
			end
		end),

		-- Reset state cleanly on respawn
		LocalPlayer.CharacterAdded:Connect(function(newCharacter)
			if self.IsFirstPerson then
				-- New character spawned, restore visibility on old and reset state
				self.IsFirstPerson = false
			end
			self.IsFreeLook = false

			local r = newCharacter:WaitForChild("HumanoidRootPart")
			local look = r.CFrame.LookVector
			self.CameraYaw = math.atan2(look.X, look.Z)
			self.CameraPitch = 0
		end),
	}
end

-- // Update Camera
function BaseCamera:Update(dt)
	local character = LocalPlayer.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	self.RaycastParams.FilterDescendantsInstances = { character }

	-- ALWAYS handle mouse input first
	local mouseDelta = InputService:GetMouseDelta()
	local sensitivity = getOffset("rotationSpeed", 0.25)
	self.CameraYaw   += math.rad(-mouseDelta.X * sensitivity)
	self.CameraPitch -= math.rad(mouseDelta.Y * sensitivity)
	self.CameraPitch  = math.clamp(self.CameraPitch, PITCH_CLAMP_MIN, PITCH_CLAMP_MAX)

	-- Handle mouse behavior in free look
	if self.IsFreeLook then
		if InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			InputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			InputService.MouseIconEnabled = false
		else
			InputService.MouseBehavior = Enum.MouseBehavior.Default
			InputService.MouseIconEnabled = true
		end
	end

	-- FIRST-PERSON MODE
	if self.IsFirstPerson then
		local head = character:FindFirstChild("Head") :: BasePart?
		if head then
			-- Eye level: centre of head + a small upward offset
			local eyePosition = head.Position + Vector3.new(0, head.Size.Y * 0.3, 0)
			local rotation = CFrame.Angles(0, self.CameraYaw, 0) * CFrame.Angles(self.CameraPitch, 0, 0)
			Camera.CFrame = CFrame.new(eyePosition) * rotation
			Camera.FieldOfView = self.BaseFOV

			-- Rotate body to face camera yaw (instant snap feels most natural in FP)
			local _, currentYaw, _ = root.CFrame:ToOrientation()
			local deltaYaw = math.atan2(math.sin(self.CameraYaw - currentYaw), math.cos(self.CameraYaw - currentYaw))
			local turnSpeed = getOffset("characterTurnSpeed", 12)
			local step = math.clamp(deltaYaw, -turnSpeed * dt, turnSpeed * dt)
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, currentYaw + step, 0)

			-- Neck pitch in first person
			local upperTorso = character:FindFirstChild("UpperTorso")
			local neck = upperTorso and upperTorso:FindFirstChild("Neck")
			if neck and neck:IsA("Motor6D") then
				local pitch = math.clamp(self.CameraPitch, HEAD_PITCH_CLAMP_MIN, HEAD_PITCH_CLAMP_MAX)
				neck.Transform = CFrame.Angles(pitch * HEAD_PITCH_MULTIPLIER, 0, 0)
			end
		end
		return
	end

	-- Character rotation — only when NOT in free look
	if not self.IsFreeLook then
		local _, currentYaw, _ = root.CFrame:ToOrientation()
		local deltaYaw = math.atan2(math.sin(self.CameraYaw - currentYaw), math.cos(self.CameraYaw - currentYaw))
		local turnSpeed = getOffset("characterTurnSpeed", 12)
		local step = math.clamp(deltaYaw, -turnSpeed * dt, turnSpeed * dt)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, currentYaw + step, 0)
	end

	-- Head/neck tilt
	local upperTorso = character:FindFirstChild("UpperTorso")
	local neck = upperTorso and upperTorso:FindFirstChild("Neck")
	if neck and neck:IsA("Motor6D") then
		local pitch = math.clamp(self.CameraPitch, HEAD_PITCH_CLAMP_MIN, HEAD_PITCH_CLAMP_MAX)
		neck.Transform = CFrame.Angles(pitch * HEAD_PITCH_MULTIPLIER, 0, 0)
	end

	-- Speed-based zoom
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local sprintAlpha = 0
	if speed >= SPRINT_THRESHOLD then
		sprintAlpha = math.clamp((speed - SPRINT_THRESHOLD) / (SPRINT_MAX_SPEED - SPRINT_THRESHOLD), 0, 1)
	end

	-- Distance target
	local baseDistance: number
	if self.IsFreeLook then
		baseDistance = self.BaseDistance * FREE_LOOK_DISTANCE_MULTIPLIER
	else
		baseDistance = self.BaseDistance
	end
	local effectiveSprintDist = (self.IsFirstPerson or self.IsFreeLook) and baseDistance or self.SprintDistance
	self.TargetDistance = baseDistance + (effectiveSprintDist - baseDistance) * sprintAlpha

	-- FOV
	local targetFOV = self.BaseFOV + (self.MaxFOV - self.BaseFOV) * sprintAlpha

	-- Shoulder
	local targetShoulder = (self.IsFreeLook or self.IsFirstPerson) and 0 or self.TargetShoulder
	self.CurrentShoulder = smooth(self.CurrentShoulder, targetShoulder, SHOULDER_SMOOTH_SPEED, dt)
	self.CurrentDistance = smooth(self.CurrentDistance, self.TargetDistance, DISTANCE_SMOOTH_SPEED, dt)
	local fovSpeed = (targetFOV > self.CurrentFOV) and FOV_INCREASE_SPEED or FOV_DECREASE_SPEED
	self.CurrentFOV = smooth(self.CurrentFOV, targetFOV, fovSpeed, dt)
	Camera.FieldOfView = self.CurrentFOV

	-- Camera position
	local rotation = CFrame.Angles(0, self.CameraYaw, 0) * CFrame.Angles(self.CameraPitch, 0, 0)
	local heightOffset: number = getOffset("heightOffset", 2)
	local focusPoint = root.Position + Vector3.new(0, heightOffset, 0)
	local desiredPosition = focusPoint + rotation.RightVector * self.CurrentShoulder - rotation.LookVector * self.CurrentDistance

	-- Collision
	local direction = desiredPosition - focusPoint
	local ray = Workspace:Raycast(focusPoint, direction, self.RaycastParams)
	local finalPosition = ray and (ray.Position + ray.Normal * COLLISION_OFFSET) or desiredPosition

	-- Smooth lerp
	local targetCFrame = CFrame.new(finalPosition) * rotation
	local camAlpha = 1 - math.exp(-CAMERA_SMOOTH_SPEED * dt)
	self.CameraCFrame = self.CameraCFrame and self.CameraCFrame:Lerp(targetCFrame, camAlpha) or targetCFrame
	Camera.CFrame = self.CameraCFrame
end

function BaseCamera:End()
	-- Restore character visibility if ending while in first person
	local character = LocalPlayer.Character
	if character and self.IsFirstPerson then
		setFirstPersonVisibility(character, false)
	end

	for _, connection in pairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}

	Camera.CameraType = Enum.CameraType.Custom
	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	InputService.MouseBehavior = Enum.MouseBehavior.Default
	InputService.MouseIconEnabled = true
end

-- Initialize camera
local myCameraInfo: Types.Camera_Type = {
	name = "BasicCamera",
	priority = 1,
	Connections = {},
}
local myCamera = BaseCamera.new(myCameraInfo)
myCamera:Start()

return myCamera