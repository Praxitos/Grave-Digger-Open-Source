--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.Parent.BaseTool)
local Util = require(script.Parent.Parent.Parent.Util)

local Holster_Folder = ReplicatedStorage.Shared.Assets.Holsters:FindFirstChild("Gun Holsters")
local Tool_Folder = ReplicatedStorage.Shared.Assets.ToolModels

local PrinceRifle = {}
PrinceRifle.__index = PrinceRifle
setmetatable(PrinceRifle, { __index = BaseTool })

export type PrinceRifle = typeof(setmetatable({} :: {
	className: "PrinceRifle",
	name: string,

	item_image: string,
	Designation: string,

	holster_reference: Instance?,
	actual_holster: Model?,

	model_reference: Model?,
	actual_model: Model?,

	damage: number,

	Caster: any,
	CasterBehavior: any,

	motor_6d: Motor6D?,
	_motorOriginal: {
		C0: CFrame,
		C1: CFrame,
		Part0: BasePart?,
		Part1: BasePart?
	}?,

	_aimConnection: RBXScriptConnection?,
	_inputBeganConn: RBXScriptConnection?,
	_inputEndedConn: RBXScriptConnection?,
}, {} :: typeof(PrinceRifle)))

--////////////////////////////////////////////////////////

function PrinceRifle.new(info: Types.BaseToolCreateInfo): PrinceRifle
	local self = setmetatable(BaseTool.new(info), PrinceRifle)

	self.className = "PrinceRifle"

	self.item_image = "rbxassetid://17496049645"
	self.Designation = "Primary"

	self.holster_reference =
		Holster_Folder and Holster_Folder:FindFirstChild("PrinceRifleHolster")

	self.model_reference = Tool_Folder:FindFirstChild("PrinceRifle")

	self.motor_6d_data = {
		Parent = "Left Arm",
		Part0 = "Left Arm",
		Part1 = self.model_reference
			and self.model_reference:FindFirstChild("PrinceRifle_Middle"),
		C0 = CFrame.new(0.254, -1.703, -0.566)
			* CFrame.Angles(math.rad(0.979), math.rad(-90), math.rad(90))
	}

	self.animations = {
		Draw    = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.PrinceRifle.PrinceRifle_Draw,
		Hold    = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.PrinceRifle.PrinceRifle_Held,
		Unequip = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.PrinceRifle.PrinceRifle_Unequip,
		Aim     = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.PrinceRifle.PrinceRifle_Aim,
		Fire    = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.PrinceRifle.PrinceRifle_Fire,
		Cycle   = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.PrinceRifle.PrinceRifle_Cycle,
	}

	self.damage = 25
	self.unequip_wait = false
	self.Aiming = false
	self.Cycled = true

	self._aimConnection = nil
	self._motorOriginal = nil

	--------------------------------------------------
	-- FastCast
	--------------------------------------------------

	self.Caster, self.CasterBehavior = Util.setupFastCast({
		bulletTemplate  = ReplicatedStorage.Shared.Assets.Effects.Shooting.Bullet,
		bulletContainer = workspace,
		onHit = function(cast, result, cosmeticBullet)
			print("Hit:", result.Instance, result.Position)
		end,
	})

	--------------------------------------------------
	-- Input Handling (cleaned up)
	--------------------------------------------------

	self._inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:aim()
		end
	end)

	self._inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:aim()
		end
	end)

	return self
end

--////////////////////////////////////////////////////////
-- Motor6D tracking
--////////////////////////////////////////////////////////

function PrinceRifle:_cacheMotor6D()
	if not self.motor_6d then return end

	self._motorOriginal = {
		C0 = self.motor_6d.C0,
		C1 = self.motor_6d.C1,
		Part0 = self.motor_6d.Part0,
		Part1 = self.motor_6d.Part1,
	}
end

function PrinceRifle:_resetMotor6D()
	if not self.motor_6d or not self._motorOriginal then return end

	local motor = self.motor_6d
	local targetC0 = self._motorOriginal.C0
	local targetC1 = self._motorOriginal.C1

	local conn
	conn = RunService.PreSimulation:Connect(function()
		motor.C0 = motor.C0:Lerp(targetC0, 0.15)
		motor.C1 = motor.C1:Lerp(targetC1, 0.15)

		if (motor.C0.Position - targetC0.Position).Magnitude < 0.001 then
			conn:Disconnect()
		end
	end)
end

--////////////////////////////////////////////////////////
-- Aim tracking
--////////////////////////////////////////////////////////

function PrinceRifle:_startAimTracking()
	local character = Players.LocalPlayer.Character
	if not character then return end

	local torso = character:FindFirstChild("Torso")
	if not torso then return end

	local leftShoulder = torso:FindFirstChild("Left Shoulder")
	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	if not leftShoulder or not rightShoulder then return end

	self._leftShoulder = leftShoulder
	self._rightShoulder = rightShoulder
	self._leftShoulderC0 = leftShoulder.C0
	self._rightShoulderC0 = rightShoulder.C0

	self._aimConnection = RunService.PreSimulation:Connect(function()
		if not self.Aiming then return end

		local camera = workspace.CurrentCamera
		local pitch = camera.CFrame:ToEulerAnglesYXZ()

		local aimAngle = math.clamp(select(1, pitch), math.rad(-60), math.rad(60))

		leftShoulder.C0 = leftShoulder.C0:Lerp(
			self._leftShoulderC0 * CFrame.Angles(0, 0, -aimAngle),
			0.1
		)

		rightShoulder.C0 = rightShoulder.C0:Lerp(
			self._rightShoulderC0 * CFrame.Angles(0, 0, aimAngle),
			0.1
		)
	end)
end

function PrinceRifle:_stopAimTracking()
	if self._aimConnection then
		self._aimConnection:Disconnect()
		self._aimConnection = nil
	end

	if self._leftShoulder and self._leftShoulderC0 and self._rightShoulder and self._rightShoulderC0 then
		local leftShoulder = self._leftShoulder
		local rightShoulder = self._rightShoulder
		local leftTargetC0 = self._leftShoulderC0
		local rightTargetC0 = self._rightShoulderC0

		local resetConn
		resetConn = RunService.PreSimulation:Connect(function()
			leftShoulder.C0 = leftShoulder.C0:Lerp(leftTargetC0, 0.1)
			rightShoulder.C0 = rightShoulder.C0:Lerp(rightTargetC0, 0.1)

			if (leftShoulder.C0.Position - leftTargetC0.Position).Magnitude < 0.001 then
				resetConn:Disconnect()
			end
		end)
	end

	self._leftShoulder = nil
	self._rightShoulder = nil
	self._leftShoulderC0 = nil
	self._rightShoulderC0 = nil
end

--////////////////////////////////////////////////////////
-- Tool actions
--////////////////////////////////////////////////////////

function PrinceRifle:aim()
	for _, child in pairs(self.RegisteredAnimations) do
		child:Stop()
	end

	if not self.Aiming then
		self.RegisteredAnimations.Aim:Play()
		self.Aiming = true
		self:_startAimTracking()
	else
		self:_stopAimTracking()

		self.RegisteredAnimations.Aim.TimePosition = 1
		self.RegisteredAnimations.Aim:AdjustSpeed(-1)

		self.RegisteredAnimations.Aim.Stopped:Once(function()
			self.RegisteredAnimations.Aim:AdjustSpeed(1)
		end)

		self.RegisteredAnimations.Hold:Play()
		self.Aiming = false
	end
end

function PrinceRifle:cycle()
	for _, child in pairs(self.RegisteredAnimations) do
		child:Stop()
	end

	self.RegisteredAnimations.Cycle:Play()
	self.RegisteredAnimations.Cycle.Stopped:Wait()

	self.Cycled = true

	if self.Aiming then
		self.RegisteredAnimations.Aim:Play()
	else
		self.RegisteredAnimations.Hold:Play()
	end
end

function PrinceRifle:fire()
	local camera = workspace.CurrentCamera

	local muzzle = self.actual_model and self.actual_model:FindFirstChild("PrinceRifle_Muzzle")
	if not muzzle then return end

	local origin = muzzle.Position
	local direction = camera.CFrame.LookVector.Unit

	self.Caster:Fire(origin, direction, 1000, self.CasterBehavior)
	self.RegisteredAnimations.Fire:Play()
	self.Cycled = false
end

function PrinceRifle:activate()
	if not self.actual_model then return end

	if not self.Cycled then
		self:cycle()
		return
	end

	if not self.Aiming then return end

	self:fire()
end

--////////////////////////////////////////////////////////
-- Unequip / cleanup
--////////////////////////////////////////////////////////

function PrinceRifle:_on_unequip()
	for _, child in pairs(self.RegisteredAnimations) do
		child:Stop()
	end

	self:_stopAimTracking()
	self:_resetMotor6D()

	self.Aiming = false
	self.Cycled = true
end

function PrinceRifle:Destroy()
	if self._inputBeganConn then
		self._inputBeganConn:Disconnect()
	end
	if self._inputEndedConn then
		self._inputEndedConn:Disconnect()
	end

	self:_stopAimTracking()
	self:_resetMotor6D()
end

return PrinceRifle