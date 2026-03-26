--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local utilities_module = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("Util")
)

local LOCAL_PLAYER = Players.LocalPlayer

-- // Tuning (shared defaults; subclasses can override on self)

local AIM_PITCH_LIMIT  = math.rad(60)
local AIM_LERP_ALPHA   = 0.1
local MOTOR_LERP_ALPHA = 0.15
local MOTOR_SNAP_DIST  = 0.001

local BaseTool = {}
BaseTool.__index = BaseTool


export type BaseTool = typeof(setmetatable({} :: {
	className: "BaseTool",
	name: string,

	-- core
	tool: Tool?,
	model_reference: Model?,
	actual_model: Model?,

	-- holster
	holster_reference: Instance?,
	actual_holster: Model?,

	-- animations
	animations: {[string]: Animation}?,
	RegisteredAnimations: {[string]: AnimationTrack}?,

	-- motor6d
	motor_6d_data: {
		Parent: string,
		Part0: string,
		Part1: string | BasePart,
		C0: CFrame
	}?,
	motor_6d: Motor6D?,
	_motorOriginal: { C0: CFrame, C1: CFrame, Part0: BasePart?, Part1: BasePart? }?,

	-- shoulder / aim state (used by armed tools)
	current_shoulder: string,
	Aiming: boolean,
	_aimConnection: RBXScriptConnection?,
	_leftShoulder: Motor6D?,
	_rightShoulder: Motor6D?,
	_leftShoulderC0: CFrame?,
	_rightShoulderC0: CFrame?,

	-- internal
	_activationConnection: RBXScriptConnection?,
	_shoulderChangedConn:  RBXScriptConnection?,
}, {} :: typeof(BaseTool)))

-- // Constructor

function BaseTool.new(BaseToolCreateInfo: Types.BaseToolCreateInfo): BaseTool
	local self = setmetatable({}, BaseTool)

	self.className = "BaseTool"
	self.name = BaseToolCreateInfo.name

	self.tool = nil
	self.actual_model = nil
	self.actual_holster = nil
	self.RegisteredAnimations = nil

	self.Aiming           = false
	self.current_shoulder = "Right"

	self._activationConnection = nil
	self._shoulderChangedConn  = nil
	self._aimConnection        = nil

	return self
end

-- // Lifecycle: called when tool is given

function BaseTool:on_give(tool: Tool, holster: Model?, model: Model?)
	self.tool = tool

	-- animations
	if self.animations then
		self.RegisteredAnimations = utilities_module.register_animations(
			LOCAL_PLAYER,
			self.animations
		)
		if not self.RegisteredAnimations then
			warn("[" .. self.className .. "] Failed to register animations")
		end
	end

	-- holster resolution
	if holster then
		self.actual_holster = holster
	elseif self.holster_reference then
		self.actual_holster = utilities_module.reverse_search_holster(
			LOCAL_PLAYER,
			self.holster_reference.Name
		)
	else
		warn("[" .. self.className .. "] Missing holster_reference")
	end

	-- activation binding
	if self._activationConnection then
		self._activationConnection:Disconnect()
	end
	self._activationConnection = tool.Activated:Connect(function()
		self:activate()
	end)

	-- optional subclass hook
	if self._on_give then
		self:_on_give(tool, holster, model)
	end
end

-- // Equip / Unequip

function BaseTool:equip()
	if not self.tool then return end

	local character = LOCAL_PLAYER.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid:EquipTool(self.tool)

	if self.RegisteredAnimations then
		local draw = self.RegisteredAnimations.Draw
		local hold = self.RegisteredAnimations.Hold
		if draw then draw:Play() end
		if hold then hold:Play() end
	end

	if self.model_reference then
		self.actual_model = utilities_module.reverse_search_model(
			LOCAL_PLAYER,
			self.model_reference.Name
		)
		if not self.actual_model then
			warn("[" .. self.className .. "] Failed to find model")
		end
	end

	if self._on_equip then
		self:_on_equip()
	end
end

function BaseTool:unequip()
	if not self.tool then return end

	local character = LOCAL_PLAYER.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- 1. Let the subclass cancel in-flight coroutines and disconnect input FIRST,
	--    while animations are still alive so any Stopped:Wait() can resolve.
	if self._on_unequip then
		self:_on_unequip()
	end

	-- 2. Now it is safe to stop all animations — no coroutine is waiting on them.
	if self.RegisteredAnimations then
		for _, anim in pairs(self.RegisteredAnimations) do
			anim:Stop()
		end
	end

	-- 3. Unequip the tool from the humanoid.
	humanoid:UnequipTools()

	-- 4. Play the unequip animation if present.
	if self.RegisteredAnimations and self.RegisteredAnimations.Unequip then
		self.RegisteredAnimations.Unequip:Play()
		if self.unequip_wait == true then
			self.RegisteredAnimations.Unequip.Stopped:Wait()
		end
	end

	self.actual_model = nil
end

-- // Shared Helpers

function BaseTool:activate()
	error(self.className .. " missing activate()")
end

function BaseTool:_if_sprinting()
	return LOCAL_PLAYER.Character:GetAttribute("Sprinting")
end

function BaseTool:notify(text: string)
	local Notifications_util = require(
		LOCAL_PLAYER.PlayerGui:WaitForChild("Notifications"):WaitForChild("Utils")
	)
	Notifications_util.send_notification(LOCAL_PLAYER, text)
end

function BaseTool:ammo_check()
	if not self.RegisteredAnimations or not self.RegisteredAnimations.Check then
		print("Has no check animation, assuming there is no built in check system...")
		return
	end
	if self.Firing or self.Reloading or self.Cycling or self.Alting then return end

	local ammo_check_part
	local ammo_check_utils

	if not workspace.CurrentCamera:FindFirstChild("Ammo_Check") then
		ammo_check_part = game.ReplicatedStorage.Shared.Assets.Effects.AmmoUI.Ammo_Check:Clone()
		ammo_check_part.Parent = workspace.CurrentCamera
		ammo_check_utils = require(ammo_check_part.Utils)
	else
		ammo_check_part = workspace.CurrentCamera.Ammo_Check
		ammo_check_utils = require(workspace.CurrentCamera.Ammo_Check.Utils)
	end

	self.RegisteredAnimations.Check:Play()

	local hrp = LOCAL_PLAYER.Character.HumanoidRootPart
	ammo_check_part.Position = hrp.Position + hrp.CFrame.RightVector * 2 + Vector3.new(0, 1.5, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ammo_check_part
	weld.Part1 = hrp
	weld.Parent = ammo_check_part

	local percentage = math.clamp(self.Capacity / self.Max_Capacity, 0, 1)
	ammo_check_utils.utils(self.Ammo_Type, percentage, false)
end

-- // Shoulder Tracking (shared by all armed tools)
--
-- Call _initShoulderTracking() from your constructor.
-- Override _onShoulderChanged() in your subclass to swap aim anims.

function BaseTool:_initShoulderTracking()
	if not RunService:IsClient() then return end
	local player = Players.LocalPlayer
	self.current_shoulder = player:GetAttribute("Current_Shoulder") or "Right"

	if self._shoulderChangedConn then
		self._shoulderChangedConn:Disconnect()
	end

	self._shoulderChangedConn = player:GetAttributeChangedSignal("Current_Shoulder"):Connect(function()
		self.current_shoulder = player:GetAttribute("Current_Shoulder") or "Right"
		-- re-cache aim C0s so the tracker doesn't fight the post-swap animation pose
		if self._aimConnection and self._leftShoulder and self._rightShoulder then
			-- give the animation one frame to settle before re-caching
			task.defer(function()
				if self._leftShoulder and self._rightShoulder then
					self._leftShoulderC0  = self._leftShoulder.C0
					self._rightShoulderC0 = self._rightShoulder.C0
				end
			end)
		end
		if self._onShoulderChanged then
			self:_onShoulderChanged()
		end
	end)
end

-- Disconnects the shoulder attribute watcher. Call on unequip so the signal
-- does not fire and try to swap aim anims on an unequipped tool.
function BaseTool:_stopShoulderTracking()
	if self._shoulderChangedConn then
		self._shoulderChangedConn:Disconnect()
		self._shoulderChangedConn = nil
	end
end

-- // Aim Tracking (shared by all shoulder-aimed tools)

-- Starts per-frame shoulder pitch tracking.
-- Re-entrant safe: a second call while already tracking is a no-op.
function BaseTool:_startAimTracking()
	if self._aimConnection then return end -- already running

	local character = LOCAL_PLAYER.Character
	if not character then return end

	local torso = character:FindFirstChild("Torso")
	if not torso then return end

	local leftShoulder  = torso:FindFirstChild("Left Shoulder")
	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	if not leftShoulder or not rightShoulder then return end

	self._leftShoulder    = leftShoulder
	self._rightShoulder   = rightShoulder
	-- cache the current (resting) C0 — the animation system owns these values
	self._leftShoulderC0  = leftShoulder.C0
	self._rightShoulderC0 = rightShoulder.C0

	local pitchLimit = (self :: any).AIM_PITCH_LIMIT or AIM_PITCH_LIMIT
	local lerpAlpha  = (self :: any).AIM_LERP_ALPHA  or AIM_LERP_ALPHA

	self._aimConnection = RunService.PreSimulation:Connect(function()
		if not self.Aiming then return end
		-- always lerp from the motor's *current* value toward (restC0 * pitchOffset)
		-- this means shoulder-swap re-caches are immediately respected
		local pitch    = workspace.CurrentCamera.CFrame:ToEulerAnglesYXZ()
		local aimAngle = math.clamp(pitch, -pitchLimit, pitchLimit)

		leftShoulder.C0 = leftShoulder.C0:Lerp(
			self._leftShoulderC0  * CFrame.Angles(0, 0, -aimAngle), lerpAlpha
		)
		rightShoulder.C0 = rightShoulder.C0:Lerp(
			self._rightShoulderC0 * CFrame.Angles(0, 0,  aimAngle), lerpAlpha
		)
	end)
end

-- Stops tracking and snaps shoulders back to their resting poses.
function BaseTool:_stopAimTracking()
	if self._aimConnection then
		self._aimConnection:Disconnect()
		self._aimConnection = nil
	end
	-- snap back cleanly; guard in case they were never set
	if self._leftShoulder and self._leftShoulderC0 then
		self._leftShoulder.C0 = self._leftShoulderC0
	end
	if self._rightShoulder and self._rightShoulderC0 then
		self._rightShoulder.C0 = self._rightShoulderC0
	end
	self._leftShoulder    = nil
	self._rightShoulder   = nil
	self._leftShoulderC0  = nil
	self._rightShoulderC0 = nil
end

-- // Motor6D Helpers (shared by armed tools that weld a model to an arm)

function BaseTool:_cacheMotor6D()
	if not self.motor_6d then return end
	self._motorOriginal = {
		C0    = self.motor_6d.C0,
		C1    = self.motor_6d.C1,
		Part0 = self.motor_6d.Part0,
		Part1 = self.motor_6d.Part1,
	}
end

-- Lerps the motor back to its cached transform, then disconnects.
function BaseTool:_resetMotor6D()
	if not self.motor_6d or not self._motorOriginal then return end
	local motor    = self.motor_6d
	local targetC0 = self._motorOriginal.C0
	local targetC1 = self._motorOriginal.C1
	local snapDist = (self :: any).MOTOR_SNAP_DIST or MOTOR_SNAP_DIST
	local alpha    = (self :: any).MOTOR_LERP_ALPHA or MOTOR_LERP_ALPHA
	local conn
	conn = RunService.PreSimulation:Connect(function()
		motor.C0 = motor.C0:Lerp(targetC0, alpha)
		motor.C1 = motor.C1:Lerp(targetC1, alpha)
		if (motor.C0.Position - targetC0.Position).Magnitude < snapDist then
			conn:Disconnect()
		end
	end)
end

-- // Animation Helpers (shared)

-- Stops every registered animation except the given one (pass nil to stop all).
function BaseTool:_stopAllExcept(exception: AnimationTrack?)
	if not self.RegisteredAnimations then return end
	for _, track in pairs(self.RegisteredAnimations) do
		if track ~= exception then
			track:Stop()
		end
	end
end


-- // Effect Automation
function BaseTool:emit_effect(
	effect: Part,
	target_tables: {string},
	parent: Instance,
	emit_count: number,
	attach_to_parent: boolean
)
	print("Emitting effect received with:", effect.Name, target_tables, parent.Name, emit_count)

	emit_count = emit_count or 10

	print("Children count:", #effect:GetChildren())

	for _, child in pairs(effect:GetDescendants()) do
		print("Checking:", child.Name, child.ClassName)

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

			-- Offset relative to muzzle orientation
			local offset = CFrame.new(-0.1, 0, -2)
			part.CFrame = parent.CFrame * offset

			clone.Parent = part
			container = part
		end

		print("Cloned:", child.Name, "->", clone.Parent.Name)

		if clone:IsA("ParticleEmitter") then
			clone.Enabled = true
			clone:Emit(emit_count)
			print("EMITTED:", child.Name, emit_count)

			-- Cleanup based on lifetime
			local lifetime = clone.Lifetime.Max

			task.delay(lifetime + 0.1, function()
				if attach_to_parent then
					if clone then
						clone:Destroy()
						print("Cleaned emitter:", child.Name)
					end
				else
					if container then
						container:Destroy()
						print("Cleaned container part")
					end
				end
			end)
		end
	end

	print("Effect emitted")
end

-- // Cleanup

function BaseTool:destroy()
	if self._activationConnection then
		self._activationConnection:Disconnect()
		self._activationConnection = nil
	end
	self:_stopShoulderTracking()
	self:_stopAimTracking()
	self:_resetMotor6D()

	if self.actual_model then
		self.actual_model:Destroy()
		self.actual_model = nil
	end
end

return BaseTool