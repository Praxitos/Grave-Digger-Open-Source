------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------

local InputService      = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local PlayerService     = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

local CameraClass = require(script.Parent.Parent.Parent.Parent.Library.Classes.Miscellanous.CameraClass)
local main_util   = require(ReplicatedStorage.Shared.Library.Util)

------------------------------------------------------------------------
-- Camera Values
------------------------------------------------------------------------

local PITCH_MIN = math.rad(-70)
local PITCH_MAX = math.rad(70)

local CAM_SMOOTH_SPEED    = 26

local DEFAULT_DISTANCE    = 5
local DEFAULT_SIDE        = 1.8
local DEFAULT_HEIGHT      = 1.6
local SHOULDER_LERP_SPEED = 45

local SPRINT_DISTANCE_ADD = 0
local BASE_WALKSPEED      = 10
local MAX_WALKSPEED       = 18

local BASE_FOV  = 90
local MAX_FOV   = 105
local FOV_SPEED = 8

local ZOOM_MIN        = 1.5
local ZOOM_MAX        = 3
local ZOOM_STEP       = 0.6
local ZOOM_LERP_SPEED = 45

local COLLISION_OFFSET = 0.25

local FREELOOK_PAN_SPEED      = 22
local FREELOOK_PAN_THRESHOLD  = 0.25
local FREELOOK_ORBIT_DISTANCE = 5

local FIRST_PERSON_DEBOUNCE = 0.2
local SHOULDER_DEBOUNCE     = 0.2
local FREELOOK_DEBOUNCE     = 0.15

local RECOIL_DECAY_SPEED = 16

local HOLD_BREATH_FOV      = 40
local HOLD_BREATH_IN_TIME  = 1
local HOLD_BREATH_OUT_TIME = 0.5
local AIM_FOV              = 50
local AIM_FOV_IN_TIME      = 0.15
local AIM_FOV_OUT_TIME     = 0.12


local FIRST_PERSON_SMOOTH = 10 
local FIRST_PERSON_EXCLUDED = {
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}
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

local Aiming_Screengui        = LocalPlayer.PlayerGui:WaitForChild("Aiming")
local hold_breath_image_label = Aiming_Screengui:WaitForChild("hold_breath")

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
	return a + (b - a) * math.clamp(speed * dt, 0, 1)
end

local function lerpVec(a: Vector3, b: Vector3, speed: number, dt: number): Vector3
	return a:Lerp(b, math.clamp(speed * dt, 0, 1))
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
	LocalPlayer.PlayerGui.Aiming.Regular_Crosshair.Visible = true
	LocalPlayer:SetAttribute("FreeLook", nil)
end

------------------------------------------------------------------------
-- FOV tween helper
------------------------------------------------------------------------

local activeFOVTween: Tween? = nil

local function tweenFOV(target: number, duration: number)
	if activeFOVTween then
		activeFOVTween:Cancel()
	end
	activeFOVTween = TweenService:Create(
		Camera,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = target }
	)
	activeFOVTween:Play()
end

local activeFPTween: Tween? = nil

local function tweenFirstPerson(char: Model, entering: boolean)
	if activeFPTween then
		activeFPTween:Cancel()
	end

	local head  = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("Torso")

	if entering then
		if head  then head.LocalTransparencyModifier  = 0 end
		if torso then torso.LocalTransparencyModifier = 0 end

		local targetT = 1
		local info    = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("BasePart") and not FIRST_PERSON_EXCLUDED[desc.Name] then
				TweenService:Create(desc, info, {
					LocalTransparencyModifier = targetT
				}):Play()
			end
		end
	else
		local targetT = 0
		local info    = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("BasePart") and not FIRST_PERSON_EXCLUDED[desc.Name] then
				TweenService:Create(desc, info, {
					LocalTransparencyModifier = targetT
				}):Play()
			end
		end
	end
end

------------------------------------------------------------------------
-- Hold Breath
------------------------------------------------------------------------

local holdBreathTweens: {Tween} = {}

local function cancelHoldBreathTweens()
	for _, t in ipairs(holdBreathTweens) do
		t:Cancel()
	end
	table.clear(holdBreathTweens)
end

local function holdBreath()
	cancelHoldBreathTweens()
	if activeFOVTween then activeFOVTween:Cancel() end

	local imageTween = TweenService:Create(
		hold_breath_image_label,
		TweenInfo.new(HOLD_BREATH_IN_TIME),
		{ ImageTransparency = 0 }
	)
	local fovTween = TweenService:Create(
		Camera,
		TweenInfo.new(HOLD_BREATH_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = HOLD_BREATH_FOV }
	)

	table.insert(holdBreathTweens, imageTween)
	table.insert(holdBreathTweens, fovTween)

	imageTween:Play()
	fovTween:Play()
end

local function releaseBreath(isAiming: boolean)
	cancelHoldBreathTweens()
	if activeFOVTween then activeFOVTween:Cancel() end

	local imageTween = TweenService:Create(
		hold_breath_image_label,
		TweenInfo.new(HOLD_BREATH_OUT_TIME),
		{ ImageTransparency = 1 }
	)
	local targetFOV = isAiming and AIM_FOV or BASE_FOV
	local fovTween = TweenService:Create(
		Camera,
		TweenInfo.new(HOLD_BREATH_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = targetFOV }
	)

	table.insert(holdBreathTweens, imageTween)
	table.insert(holdBreathTweens, fovTween)

	imageTween:Play()
	fovTween:Play()

	main_util.applyRecoil(100, 10, 25)
end

------------------------------------------------------------------------
-- Constructor
------------------------------------------------------------------------

function BaseCamera.new(cameraInfo)
	local self = CameraClass.new(cameraInfo)
	setmetatable(self, {__index = BaseCamera})
	self.CameraPosition = Camera.CFrame.Position
	self.priority = 0
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
	LocalPlayer.PlayerGui.Aiming.Regular_Crosshair.Visible = true

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

	self.RecoilPitch = 0
	self.RecoilYaw   = 0

	self.IsAiming     = false
	self.IsHoldBreath = false

	-- first person transparency cache
	self.TransparencyCache = {}

	local character = LocalPlayer.Character
	local root      = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		self.CameraYaw   = yawFromLook(root.CFrame.LookVector)
		self.FreeLookYaw = self.CameraYaw
		self.SmoothedPos = root.Position + Vector3.new(0, getOffset("heightOffset", DEFAULT_HEIGHT), 0)
	end

	self.RaycastParams            = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	------------------------------------------------------------------------
	-- First person transparency helpers
	------------------------------------------------------------------------

	local function hideCharacter(char: Model)
		self.TransparencyCache = {}
		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
				self.TransparencyCache[desc] = desc.LocalTransparencyModifier
				desc.LocalTransparencyModifier = 1
			elseif desc:IsA("Decal") then
				self.TransparencyCache[desc] = desc.Transparency
				desc.Transparency = 1
			end
		end
	end

	local function showCharacter(char: Model)
		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
				desc.LocalTransparencyModifier = self.TransparencyCache[desc] or 0
			elseif desc:IsA("Decal") then
				desc.Transparency = self.TransparencyCache[desc] or 0
			end
		end
		self.TransparencyCache = {}
	end

	self._hideCharacter = hideCharacter
	self._showCharacter = showCharacter

	------------------------------------------------------------------------
	-- Character attribute watchers
	------------------------------------------------------------------------

	local function connectCharacterAttributes(char: Model)

		char:GetAttributeChangedSignal("Aiming"):Connect(function()
			local isAiming = char:GetAttribute("Aiming") == true
			self.IsAiming = isAiming
			if not self.IsHoldBreath then
				tweenFOV(
					isAiming and AIM_FOV or BASE_FOV,
					isAiming and AIM_FOV_IN_TIME or AIM_FOV_OUT_TIME
				)
			end
		end)

		char:GetAttributeChangedSignal("HoldBreathe"):Connect(function()
			local isHolding = char:GetAttribute("HoldBreathe") ~= nil
			if isHolding and not self.IsHoldBreath then
				self.IsHoldBreath = true
				holdBreath()
			elseif not isHolding and self.IsHoldBreath then
				self.IsHoldBreath = false
				releaseBreath(self.IsAiming)
			end
		end)

		local left_arm = char:WaitForChild("Left Arm")
		left_arm.CanCollide = false
		local right_arm = char:WaitForChild("Right Arm")
		right_arm.CanCollide = false
	end

	if character then
		connectCharacterAttributes(character)
	end

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
					
					showCharacter(char)
				else
					exitFreeLook(self, char)
					local r = char and char:FindFirstChild("HumanoidRootPart")
					if r then self.CameraYaw = yawFromLook(r.CFrame.LookVector) end
					self.CameraPitch = 0

					if self.IsFirstPerson then
						tweenFirstPerson(char, true )
					end
				end

			elseif keyMatches(pressedName, firstPersonKey) then
				if self.FirstPersonDebounce then return end
				self.FirstPersonDebounce = true

				local wasFirstPerson = self.IsFirstPerson
				self.IsFirstPerson = not self.IsFirstPerson
				LocalPlayer:SetAttribute("FirstPerson", self.IsFirstPerson)

				if self.IsFreeLook then exitFreeLook(self, char) end
				self.FreeLookYaw   = self.CameraYaw
				self.FreeLookPitch = self.CameraPitch

				if char then
					tweenFirstPerson(char, self.IsFirstPerson)
				end

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
			self.IsAiming            = false
			self.IsHoldBreath        = false
			self.DeathSubject        = nil
			self.DeathOrbitYaw       = 0
			self.DeathOrbitPitch     = 0
			self.TransparencyCache   = {}
			cancelHoldBreathTweens()
			if activeFOVTween then activeFOVTween:Cancel() end
			exitFreeLook(self, newCharacter)

			local r = newCharacter:WaitForChild("HumanoidRootPart")
			self.CameraYaw     = yawFromLook(r.CFrame.LookVector)
			self.CameraPitch   = 0
			self.FreeLookYaw   = self.CameraYaw
			self.FreeLookPitch = 0
			self.SmoothedPos   = r.Position + Vector3.new(0, getOffset("heightOffset", DEFAULT_HEIGHT), 0)

			connectCharacterAttributes(newCharacter)
		end),

		LocalPlayer.Character:WaitForChild("Humanoid").Died:Connect(function()
			-- restore transparency on death
			local char = LocalPlayer.Character
			if char and self.IsFirstPerson then
				self._showCharacter(char)
			end
			self.IsFirstPerson = false

			local bodies = Workspace:FindFirstChild("Game_Details") and Workspace.Game_Details:FindFirstChild("Bodies")
			if not bodies then return end

			local dead_body = bodies:FindFirstChild(LocalPlayer.Name)
			if not dead_body then
				local conn
				conn = bodies.ChildAdded:Connect(function(child)
					if child.Name == LocalPlayer.Name then
						conn:Disconnect()
						self.DeathSubject       = child
						self.DeathOrbitYaw      = self.CameraYaw
						self.DeathOrbitPitch    = math.rad(-20)
						self.DeathOrbitDistance = 8
					end
				end)
			else
				self.DeathSubject       = dead_body
				self.DeathOrbitYaw      = self.CameraYaw
				self.DeathOrbitPitch    = math.rad(-20)
				self.DeathOrbitDistance = 8
			end
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

	local sensitivity = getOffset("rotationSpeed", 0.25) * 1.35
	local delta       = InputService:GetMouseDelta()

	------------------------------------------------------------------------
	-- Death spectate
	------------------------------------------------------------------------
	if self.DeathSubject then
		local subjectPos
		if self.DeathSubject:IsA("Model") then
			subjectPos = self.DeathSubject.PrimaryPart
				and self.DeathSubject.PrimaryPart.Position
				or getHeadPos(self.DeathSubject)
		else
			subjectPos = self.DeathSubject.Position
		end

		self.DeathOrbitYaw   += math.rad(-delta.X * sensitivity)
		self.DeathOrbitPitch += math.rad(-delta.Y * sensitivity)
		self.DeathOrbitPitch  = math.clamp(self.DeathOrbitPitch, PITCH_MIN, PITCH_MAX)

		local rot        = CFrame.Angles(0, self.DeathOrbitYaw, 0) * CFrame.Angles(self.DeathOrbitPitch, 0, 0)
		local desiredPos = subjectPos - rot.LookVector * self.DeathOrbitDistance
		self.SmoothedPos = lerpVec(self.SmoothedPos, desiredPos, CAM_SMOOTH_SPEED, dt)

		Camera.CFrame = CFrame.new(self.SmoothedPos)
			* CFrame.Angles(0, self.DeathOrbitYaw, 0)
			* CFrame.Angles(self.DeathOrbitPitch, 0, 0)
		return
	end

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

	local activeYaw   = (self.IsFreeLook and self.FreeLookYaw   or self.CameraYaw)
	local activePitch = (self.IsFreeLook and self.FreeLookPitch or self.CameraPitch)

	activeYaw   += self.RecoilYaw
	activePitch += self.RecoilPitch

	if not self.IsFreeLook then
		local curYaw    = yawFromLook(root.CFrame.LookVector)
		local diff      = math.atan2(math.sin(self.CameraYaw - curYaw), math.cos(self.CameraYaw - curYaw))
		local turnSpeed = getOffset("characterTurnSpeed", 24)
		root.CFrame     = CFrame.new(root.Position)
			* CFrame.Angles(0, curYaw + diff * math.clamp(turnSpeed * dt, 0, 1), 0)
	end

	--------------------------------------------------------------------
	-- 3. Shoulder lerp
	--------------------------------------------------------------------

	self.CurrentShoulder = lerp(self.CurrentShoulder, self.TargetShoulder, SHOULDER_LERP_SPEED, dt)

	--------------------------------------------------------------------
	-- 4. Distance & FOV
	--------------------------------------------------------------------

	self.CurrentDistance = lerp(
		self.CurrentDistance,
		math.clamp(self.TargetDistance, ZOOM_MIN, ZOOM_MAX),
		ZOOM_LERP_SPEED, dt
	)

	-- Sprint FOV — driven by walkspeed matching the sprint module ramp
	-- only runs when aiming and hold breath are not controlling FOV
	if not self.IsAiming and not self.IsHoldBreath then
		local walkspeed = humanoid.WalkSpeed
		local t = math.clamp((walkspeed - BASE_WALKSPEED) / (MAX_WALKSPEED - BASE_WALKSPEED), 0, 1)
		local targetFOV = BASE_FOV + (t * (MAX_FOV - BASE_FOV))
		Camera.FieldOfView = lerp(Camera.FieldOfView, targetFOV, FOV_SPEED, dt)
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

	if self.IsFirstPerson and not self.IsFreeLook then
		local targetPos = headPos

		self.SmoothedPos = lerpVec(
			self.SmoothedPos,
			targetPos,
			FIRST_PERSON_SMOOTH,
			dt
		)

		Camera.CFrame =
			CFrame.new(self.SmoothedPos)
			* CFrame.Angles(0, activeYaw, 0)
			* CFrame.Angles(activePitch, 0, 0)

		return

	elseif self.IsFreeLook then
		if LocalPlayer.PlayerGui.Aiming.Regular_Crosshair.Visible == true then
			LocalPlayer.PlayerGui.Aiming.Regular_Crosshair.Visible = false
		end

		if not LocalPlayer:GetAttribute("FreeLook") then
			LocalPlayer:SetAttribute("FreeLook", true)
		end

		if self.FreeLookPhase == "panning" then
			local orbitPos = headPos - rotation.LookVector * FREELOOK_ORBIT_DISTANCE
			self.SmoothedPos = self.SmoothedPos:Lerp(
				orbitPos,
				math.clamp(FREELOOK_PAN_SPEED * dt, 0, 1)
			)

			if (self.SmoothedPos - orbitPos).Magnitude < FREELOOK_PAN_THRESHOLD then
				self.SmoothedPos   = orbitPos
				self.FreeLookPhase = "orbiting"
				self.FreeLookYaw   = activeYaw
				self.FreeLookPitch = activePitch
			end

			Camera.CFrame = CFrame.new(self.SmoothedPos)
				* CFrame.Angles(0, activeYaw, 0)
				* CFrame.Angles(activePitch, 0, 0)
			return
		end

		desiredPos = headPos - rotation.LookVector * FREELOOK_ORBIT_DISTANCE
		rayOrigin  = headPos

	else
		desiredPos = focusPoint
			+ rotation.RightVector * self.CurrentShoulder
		- rotation.LookVector  * self.CurrentDistance
		rayOrigin = focusPoint
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
	-- 9. Neck rotation (follows camera pitch)
	--------------------------------------------------------------------

	local neckC0       = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0)
	local neckRotation = neckC0 * CFrame.Angles(-math.rad(activePitch * 40), 0, 0)
	if character:FindFirstChild("Torso") and character.Torso:FindFirstChild("Neck") then
		character.Torso.Neck.C0 = character.Torso.Neck.C0:Lerp(neckRotation, 0.1)
	end

	--------------------------------------------------------------------
	-- 10. Smooth + apply
	--------------------------------------------------------------------

	local alpha = math.clamp(CAM_SMOOTH_SPEED * dt, 0, 1)

	if (self.SmoothedPos - finalPos).Magnitude < 0.25 then
		self.SmoothedPos = finalPos
	else
		self.SmoothedPos = self.SmoothedPos:Lerp(finalPos, alpha)
	end

	Camera.CFrame =
		CFrame.new(self.SmoothedPos)
		* CFrame.Angles(0, activeYaw, 0)
		* CFrame.Angles(activePitch, 0, 0)
end

------------------------------------------------------------------------
-- End / Cut
------------------------------------------------------------------------

function BaseCamera:End()
	print("[CAMERASERVICE::] Ending camera:", self.name)
	for _, connection in pairs(self.Connections or {}) do
		connection:Disconnect()
	end

	-- restore character transparency if in first person
	local char = LocalPlayer.Character
	if char and self.IsFirstPerson then
		self._showCharacter(char)
	end

	LocalPlayer.PlayerGui.Aiming.Regular_Crosshair.Visible = false

	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local player = game.Players.LocalPlayer
	if player then
		game:GetService("UserInputService").MouseBehavior    = Enum.MouseBehavior.Default
		game:GetService("UserInputService").MouseIconEnabled = true
	end
end

function BaseCamera:Cut()
	print("[CAMERASERVICE::] Cutting camera:", self.name)
	self:End()
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

local myCamera = BaseCamera.new({ name = "BasicCamera", priority = 1, Connections = {} })

BaseCamera.priority = 1

return BaseCamera