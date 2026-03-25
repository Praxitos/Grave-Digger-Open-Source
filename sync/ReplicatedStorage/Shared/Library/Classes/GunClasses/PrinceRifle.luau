--!strict
--!native
--!optimize 2

-- PrinceRifle — bolt-action rifle with manual cycling, shoulder aiming, and alt mode.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local Types    = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.Parent.BaseTool)
local Util     = require(script.Parent.Parent.Parent.Util)

-- // Asset References

local Assets         = ReplicatedStorage.Shared.Assets
local Holster_Folder = Assets.Holsters:FindFirstChild("Gun Holsters")
local Tool_Folder    = Assets.ToolModels
local Anim_Folder    = Assets.Animations.Tools.Guns.PrinceRifle
local Effects_Folder = Assets.Effects.Shooting

-- // Tuning

local CYCLE_REST_TIME  = 0.15
local FIRE_RATE        = 0.3
local AIM_PITCH_LIMIT  = math.rad(60)
local AIM_LERP_ALPHA   = 0.1
local MOTOR_LERP_ALPHA = 0.15
local MOTOR_SNAP_DIST  = 0.001

-- // Class

local PrinceRifle = {}
PrinceRifle.__index = PrinceRifle
setmetatable(PrinceRifle, { __index = BaseTool })

export type PrinceRifle = typeof(setmetatable({} :: {
	className:   "PrinceRifle",
	name:        string,
	item_image:  string,
	Designation: string,

	holster_reference: Instance?,
	actual_holster:    Model?,
	model_reference:   Model?,
	actual_model:      Model?,

	damage:       number,
	Max_Capacity: number,
	Capacity:     number,
	Ammo_Type:    string,
	recoil:       number,
	recoil_count: number,

	-- state flags — only set through their owning functions
	Aiming:    boolean,
	Cycled:    boolean,
	Firing:    boolean,
	Cycling:   boolean,
	Reloading: boolean,
	Alt_Mode:  boolean,
	Alting:    boolean,

	_reloadCancelled: boolean, -- set true externally to abort reload loop cleanly

	current_shoulder: string, -- "Right" | "Left"

	Caster:         any,
	CasterBehavior: any,

	motor_6d:       Motor6D?,
	_motorOriginal: { C0: CFrame, C1: CFrame, Part0: BasePart?, Part1: BasePart? }?,

	_aimConnection:   RBXScriptConnection?,
	_leftShoulder:    Motor6D?,
	_rightShoulder:   Motor6D?,
	_leftShoulderC0:  CFrame?,
	_rightShoulderC0: CFrame?,

	_inputBeganConn: RBXScriptConnection?,
	_inputEndedConn: RBXScriptConnection?,
}, {} :: typeof(PrinceRifle)))

-- // Constructor

function PrinceRifle.new(info: Types.BaseToolCreateInfo): PrinceRifle
	local self = setmetatable(BaseTool.new(info), PrinceRifle)

	self.className   = "PrinceRifle"
	self.item_image  = "rbxassetid://17496049645"
	self.Designation = "Primary"

	self.holster_reference = Holster_Folder and Holster_Folder:FindFirstChild("PrinceRifleHolster")
	self.model_reference   = Tool_Folder:FindFirstChild("PrinceRifle")

	self.motor_6d_data = {
		Parent = "Left Arm",
		Part0  = "Left Arm",
		Part1  = self.model_reference and self.model_reference:FindFirstChild("PrinceRifle_Middle"),
		C0     = CFrame.new(0.254, -1.703, -0.566)
			* CFrame.Angles(math.rad(0.979), math.rad(-90), math.rad(90)),
	}
	
	self.Round = game.ReplicatedStorage.Shared.Assets.Rounds.PrinceRifle_Round

	self.animations = {
		Draw    = Anim_Folder.PrinceRifle_Draw,
		Hold    = Anim_Folder.PrinceRifle_Held,
		Unequip = Anim_Folder.PrinceRifle_Unequip,

		Aim      = Anim_Folder.PrinceRifle_Aim,
		Aim_Left = Anim_Folder.PrinceRifle_Aim_Left,

		Fire      = Anim_Folder.PrinceRifle_Fire,
		Fire_Left = Anim_Folder.PrinceRifle_Fire_Left,

		Cycle = Anim_Folder.PrinceRifle_Cycle,

		Reload_Empty = Anim_Folder.PrinceRifle_Reload_Empty,
		Reload_Start = Anim_Folder.PrinceRifle_Reload_Start,
		Reload_Loop  = Anim_Folder.PrinceRifle_Reload_Loop,
		Reload_End   = Anim_Folder.PrinceRifle_Reload_End,
		Reload_Alt   = Anim_Folder.PrinceRifle_Reload_Alt,

		Alt_Mode_On  = Anim_Folder.PrinceRifle_Alt_Mode_On,
		Alt_Mode_Off = Anim_Folder.PrinceRifle_Alt_Mode_Off,
		
		Check 		 = Anim_Folder.PrinceRifle_Check,
	}

	self.damage       = 25
	self.Max_Capacity = 10
	self.Capacity     = 10
	self.Ammo_Type    = "8mm Smokeless"
	self.recoil       = 10
	self.recoil_count = 6

	self.unequip_wait     = false
	self.Aiming           = false
	self.Cycled           = true
	self.Firing           = false
	self.Cycling          = false
	self.Reloading        = false
	self.Alt_Mode         = false
	self.Alting           = false
	self._reloadCancelled = false

	self.Caster, self.CasterBehavior = Util.setupFastCast({
		bulletTemplate  = Effects_Folder.Bullet,
		bulletContainer = workspace,
		onHit = function(_, result, _)
			print("Hit:", result.Instance, result.Position)
		end,
	})

	self:_initShoulderTracking()
	self:_initInput()


	return self
end

-- // Init Helpers

function PrinceRifle:_initShoulderTracking()
	if not RunService:IsClient() then return end
	local player          = Players.LocalPlayer
	self.current_shoulder = player:GetAttribute("Current_Shoulder")
	player:GetAttributeChangedSignal("Current_Shoulder"):Connect(function()
		self.current_shoulder = player:GetAttribute("Current_Shoulder")
		self:_onShoulderChanged()
	end)
end

function PrinceRifle:_initInput()
	self._inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:aim()
		elseif input.KeyCode == Enum.KeyCode.R then
			self:Reload()
		elseif input.KeyCode == Enum.KeyCode.F then
			self:set_alt()
		elseif input.KeyCode == Enum.KeyCode.T then
			self:ammo_check()
		end
	end)
	
	self._inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:aim()
		end
	end)
end

-- // Shoulder

-- swaps aim anim when shoulder flips; only touches the two aim tracks, nothing else
function PrinceRifle:_onShoulderChanged()
	if not self.Aiming or self.Cycling or self.Reloading then return end
	if self.current_shoulder == "Right" then
		self.RegisteredAnimations.Aim_Left:Stop()
		self.RegisteredAnimations.Aim:Play()
	else
		self.RegisteredAnimations.Aim:Stop()
		self.RegisteredAnimations.Aim_Left:Play()
	end
end

-- // Animation Helpers

-- stops all tracks except the given one (pass nil to stop everything)
function PrinceRifle:_stopAllExcept(exception: AnimationTrack?)
	for _, track in pairs(self.RegisteredAnimations) do
		if track ~= exception then
			track:Stop()
		end
	end
end

-- restores the correct idle pose based on current Aiming + shoulder state
function PrinceRifle:_playIdleAnimation()
	if self.Aiming then
		if self.current_shoulder == "Right" then
			self.RegisteredAnimations.Aim:Play()
		else
			self.RegisteredAnimations.Aim_Left:Play()
		end
	else
		self.RegisteredAnimations.Hold:Play()
	end
end

-- // Motor6D Helpers

function PrinceRifle:_cacheMotor6D()
	if not self.motor_6d then return end
	self._motorOriginal = {
		C0    = self.motor_6d.C0,
		C1    = self.motor_6d.C1,
		Part0 = self.motor_6d.Part0,
		Part1 = self.motor_6d.Part1,
	}
end

-- lerps motor back to cached transform, disconnects when close enough
function PrinceRifle:_resetMotor6D()
	if not self.motor_6d or not self._motorOriginal then return end
	local motor    = self.motor_6d
	local targetC0 = self._motorOriginal.C0
	local targetC1 = self._motorOriginal.C1
	local conn
	conn = RunService.PreSimulation:Connect(function()
		motor.C0 = motor.C0:Lerp(targetC0, MOTOR_LERP_ALPHA)
		motor.C1 = motor.C1:Lerp(targetC1, MOTOR_LERP_ALPHA)
		if (motor.C0.Position - targetC0.Position).Magnitude < MOTOR_SNAP_DIST then
			conn:Disconnect()
		end
	end)
end

-- // Aim Tracking

-- starts per-frame shoulder pitch tracking; guard prevents duplicate connections
function PrinceRifle:_startAimTracking()
	if self._aimConnection then return end
	local character = Players.LocalPlayer.Character
	if not character then return end
	local torso = character:FindFirstChild("Torso")
	if not torso then return end
	local leftShoulder  = torso:FindFirstChild("Left Shoulder")
	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	if not leftShoulder or not rightShoulder then return end

	self._leftShoulder    = leftShoulder
	self._rightShoulder   = rightShoulder
	self._leftShoulderC0  = leftShoulder.C0
	self._rightShoulderC0 = rightShoulder.C0

	self._aimConnection = RunService.PreSimulation:Connect(function()
		if not self.Aiming then return end
		local pitch    = workspace.CurrentCamera.CFrame:ToEulerAnglesYXZ()
		local aimAngle = math.clamp(pitch, -AIM_PITCH_LIMIT, AIM_PITCH_LIMIT)
		leftShoulder.C0  = leftShoulder.C0:Lerp(self._leftShoulderC0  * CFrame.Angles(0, 0, -aimAngle), AIM_LERP_ALPHA)
		rightShoulder.C0 = rightShoulder.C0:Lerp(self._rightShoulderC0 * CFrame.Angles(0, 0,  aimAngle), AIM_LERP_ALPHA)
	end)
end

-- stops tracking and restores shoulder resting poses
function PrinceRifle:_stopAimTracking()
	if self._aimConnection then
		self._aimConnection:Disconnect()
		self._aimConnection = nil
	end
	if self._leftShoulder and self._rightShoulder then
		self._leftShoulder.C0  = self._leftShoulderC0
		self._rightShoulder.C0 = self._rightShoulderC0
	end
	self._leftShoulder    = nil
	self._rightShoulder   = nil
	self._leftShoulderC0  = nil
	self._rightShoulderC0 = nil
end

-- // Tool Actions

-- toggles alt mode on/off with matching animation
function PrinceRifle:set_alt()
	if self.Alting or self.Reloading or self.Firing then return end
	self.Alting = true
	if self.Alt_Mode then
		self.RegisteredAnimations.Alt_Mode_Off:Play()
		self.RegisteredAnimations.Alt_Mode_Off.Stopped:Wait()
		self.Alt_Mode = false
		
		self:notify("Firemode switched to Single Fire")
	else
		self.RegisteredAnimations.Alt_Mode_On:Play()
		self.RegisteredAnimations.Alt_Mode_On.Stopped:Wait()
		self.Alt_Mode = true
		self:notify("Firemode switched to Repeating Fire")
	end
	self.Alting = false
end

-- forces aim off; only call for unequip/reload, not for normal RMB input
function PrinceRifle:end_aiming()
	self.Aiming = false
	self:_stopAimTracking()

	local aimAnim = self.RegisteredAnimations.Aim
	aimAnim.TimePosition = 1
	aimAnim:AdjustSpeed(-1)
	aimAnim.Stopped:Once(function()
		aimAnim:AdjustSpeed(1)
	end)

	if not self.Cycling then
		self.RegisteredAnimations.Hold:Play()
	end

	game.Players.LocalPlayer.Character:SetAttribute("Aiming", false)
end

function PrinceRifle:melee()
	-- placeholder
end

-- toggles aim in/out; blocked during reload and sprint
function PrinceRifle:aim()
	if PrinceRifle:_if_sprinting() then return end
	if self.Reloading then return end

	if not self.Aiming then
		self.Aiming = true
		self:_startAimTracking()
		-- only stop Hold so we don't interrupt a cycle that's in progress
		self.RegisteredAnimations.Hold:Stop()
		if self.current_shoulder == "Right" then
			self.RegisteredAnimations.Aim:Play()
		else
			self.RegisteredAnimations.Aim_Left:Play()
		end
		game.Players.LocalPlayer.Character:SetAttribute("Aiming", true)
	else
		self:end_aiming()
	end
end

-- plays bolt-cycle animation; restores idle after (reads Aiming state post-wait)
function PrinceRifle:cycle()
	if self.Cycling then return end
	self.Cycling = true
	self:_stopAllExcept(nil)
	self.RegisteredAnimations.Cycle:Play()
	self.RegisteredAnimations.Cycle.Stopped:Wait()
	self:_playIdleAnimation()
	task.wait(CYCLE_REST_TIME)
	self.Cycled  = true
	self.Cycling = false
end

-- fires one round; auto-reloads on empty, triggers _alt_reload in alt mode
function PrinceRifle:fire()
	if self.Capacity <= 0 then
		self:Reload()
		return
	end
	if self.Firing then return end
	self.Firing = true

	local muzzle = self.actual_model and self.actual_model:FindFirstChild("PrinceRifle_Muzzle")
	if not muzzle then
		self.Firing = false
		return
	end
	if PrinceRifle:_if_sprinting() then
		self.Firing = false
		return
	end

	local camera = workspace.CurrentCamera
	self.Caster:Fire(muzzle.Position, camera.CFrame.LookVector.Unit, 1000, self.CasterBehavior)

	if self.current_shoulder == "Right" then
		self.RegisteredAnimations.Fire:Play()
	else
		self.RegisteredAnimations.Fire_Left:Play()
	end

	self.Cycled   = false
	self.Capacity -= 1

	Util.applyRecoil(self.recoil, self.recoil_count, 10, false)

	task.wait(FIRE_RATE)
	self.Firing = false

	-- in alt mode just play Reload_Alt, no cycle logic
	if self.Alt_Mode then
		self:_alt_reload()
	end
end

-- alt reload: purely plays the Reload_Alt animation, no bolt cycling involved
function PrinceRifle:_alt_reload()
	self.RegisteredAnimations.Reload_Alt:Play()
	self.RegisteredAnimations.Reload_Alt.Stopped:Wait()
	self.Cycled    = true
	self.Capacity += 1
end

-- full reload sequence; forces aim off at start, no re-aim until player presses RMB again
function PrinceRifle:Reload()
	if self.Reloading then return end
	if self.Capacity >= self.Max_Capacity then return end

	-- drop aim cleanly before reload takes over animations
	if self.Aiming then
		self.Aiming = false
		self:_stopAimTracking()
		game.Players.LocalPlayer.Character:SetAttribute("Aiming", false)
	end

	self:_stopAllExcept(nil)
	self.Reloading        = true
	self._reloadCancelled = false

	if self.Capacity == 0 then
		self.RegisteredAnimations.Reload_Empty:Play()
	else
		self.RegisteredAnimations.Reload_Start:Play()
	end

	while self.Capacity < self.Max_Capacity and not self._reloadCancelled do
		self.RegisteredAnimations.Reload_Loop:Play()
		self.RegisteredAnimations.Reload_Loop.Stopped:Wait()
		if self._reloadCancelled then break end
		self.Capacity += 1
		if not self.Cycled then
			self:cycle()
		end
	end

	if not self._reloadCancelled then
		self.RegisteredAnimations.Reload_End:Play()
	else
		self:_stopAllExcept(nil)
	end

	self.Reloading        = false
	self._reloadCancelled = false

	-- no forced re-aim; player presses RMB again intentionally
	self:_playIdleAnimation()
end

-- left-click: cycles if unchambered, fires if aimed and ready
function PrinceRifle:activate()
	if not self.actual_model then return end
	if self.Firing or self.Cycling then return end
	if not self.Cycled then
		task.spawn(function() self:cycle() end)
		return
	end
	if not self.Aiming then return end
	task.spawn(function() self:fire() end)
end

-- // BaseTool Hooks

function PrinceRifle:_on_equip()
	self:_cacheMotor6D()
	game.Players.LocalPlayer.Character:SetAttribute("Sprint_Animation", "PrinceRifle")
	
	-- // event markers connections
	print("PrinceRifle: _on_equip() - Connecting event markers")
	for _, animation:AnimationTrack in pairs(self.RegisteredAnimations) do
		print("Checking" .. animation.Name, "for event tracks")
		
		if not animation:IsA("AnimationTrack") then
			print("Skipping", animation.Name, "as it is not an AnimationTrack")
			continue
		end

		animation.KeyframeReached:Connect(function(keyframeName)
			if keyframeName == "vfx_hand_shell_visible" then
				print("vfx_hand_shell_visible event triggered")
				game.Players.LocalPlayer.Character:FindFirstChild("Right Arm"):FindFirstChild(self.Round.Name).Transparency = 0
			elseif keyframeName == "vfx_hand_shell_invisible" then
				print("vfx_hand_shell_invisible event triggered")
				game.Players.LocalPlayer.Character:FindFirstChild("Right Arm"):FindFirstChild(self.Round.Name).Transparency = 1
			end
		end)	
	end
	
end

function PrinceRifle:_on_unequip()
	self._reloadCancelled = true
	self:_stopAllExcept(nil)
	self:_stopAimTracking()
	self:_resetMotor6D()

	self.Aiming    = false
	self.Cycled    = true
	self.Firing    = false
	self.Cycling   = false
	self.Reloading = false
	self.Alt_Mode  = false
	self.Alting    = false

	local char = game.Players.LocalPlayer.Character
	if char then
		char:SetAttribute("Aiming", false)
		char:SetAttribute("Sprint_Animation", nil)
	end
end

-- // Cleanup

function PrinceRifle:Destroy()
	if self._inputBeganConn then self._inputBeganConn:Disconnect() end
	if self._inputEndedConn then self._inputEndedConn:Disconnect() end
	self:_stopAimTracking()
	self:_resetMotor6D()
end

return PrinceRifle