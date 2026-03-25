--!strict
--!native
--!optimize 2

-- PrinceRifle - bolt-action rifle with manual cycling, shoulder aiming, and alt mode.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local Types    = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.Parent.BaseTool)
local Util     = require(script.Parent.Parent.Parent.Util)

-- // Asset References

local Assets         = ReplicatedStorage.Shared.Assets
local Holster_Folder = Assets.Holsters:FindFirstChild("Gun Holsters")
local Tool_Folder    = Assets.ToolModels
local Anim_Folder    = Assets.Animations.Tools.Guns.PrinceRifle
local Effects_Folder = Assets.Effects.Shooting

local muzzle_flash = Effects_Folder.Muzzle_Flash

-- // Tuning

local CYCLE_REST_TIME = 0.15
local FIRE_RATE       = 0.3

-- // Animation Priority Layers
--
--  LAYER 0 - base idle/aim:  Hold, Aim, Aim_Left
--  LAYER 1 - action overlay: Fire, Fire_Left, Cycle, Alt_Mode_On/Off
--  LAYER 2 - full takeover:  Reload_*, Draw, Unequip, Check
--
-- Rule:
--  - Layer 0 only replaces other layer 0 tracks.
--  - Layer 1 only replaces other layer 1 tracks, so base aim/hold can keep playing underneath.
--  - Layer 2 takes over completely and stops everything below it.

local ANIM_LAYER: {[string]: number} = {
	Hold         = 0,
	Aim          = 0,
	Aim_Left     = 0,

	Fire         = 1,
	Fire_Left    = 1,
	Cycle        = 1,
	Alt_Mode_On  = 1,
	Alt_Mode_Off = 1,

	Draw         = 2,
	Unequip      = 2,
	Check        = 2,
	Reload_Empty = 2,
	Reload_Start = 2,
	Reload_Loop  = 2,
	Reload_End   = 2,
	Reload_Alt   = 2,
}

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

	Aiming:    boolean,
	Cycled:    boolean,
	Firing:    boolean,
	Cycling:   boolean,
	Reloading: boolean,
	Alt_Mode:  boolean,
	Alting:    boolean,

	_reloadCancelled: boolean,

	current_shoulder: string,

	Caster:         any,
	CasterBehavior: any,

	motor_6d:       Motor6D?,
	_motorOriginal: { C0: CFrame, C1: CFrame, Part0: BasePart?, Part1: BasePart? }?,

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

		Check = Anim_Folder.PrinceRifle_Check,
	}

	self.damage       = 25
	self.Max_Capacity = 10
	self.Capacity     = 10
	self.Ammo_Type    = "8mm Smokeless"
	self.recoil       = 10
	self.recoil_count = 6

	self.unequip_wait     = false
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

-- // Animation Layer System

-- Plays `name`.
-- Layer 0 replaces only layer 0.
-- Layer 1 replaces only layer 1, preserving the base track underneath.
-- Layer 2 stops everything and takes over.
function PrinceRifle:_playAnim(name: string): AnimationTrack
	local anims = self.RegisteredAnimations
	local track = anims[name]
	assert(track, "PrinceRifle: unknown animation '" .. tostring(name) .. "'")

	local myLayer = ANIM_LAYER[name] or 0

	for trackName, layer in pairs(ANIM_LAYER) do
		local shouldStop = false

		if myLayer == 2 then
			shouldStop = layer <= 2
		else
			shouldStop = layer == myLayer
		end

		if shouldStop then
			local t = anims[trackName]
			if t and t ~= track and t.IsPlaying then
				t:Stop()
			end
		end
	end

	track:Play()
	return track
end

-- Stops all tracks at or below `maxLayer`.
function PrinceRifle:_stopLayer(maxLayer: number)
	local anims = self.RegisteredAnimations
	if not anims then return end

	for trackName, layer in pairs(ANIM_LAYER) do
		if layer <= maxLayer then
			local t = anims[trackName]
			if t and t.IsPlaying then
				t:Stop()
			end
		end
	end
end

-- Restores the correct base-layer track for the current Aiming + shoulder state,
-- but only if no action or takeover track is currently running.
function PrinceRifle:_restoreBase()
	local anims = self.RegisteredAnimations
	if not anims then return end
	if self.Reloading then return end

	for trackName, layer in pairs(ANIM_LAYER) do
		if layer >= 1 and anims[trackName] and anims[trackName].IsPlaying then
			return
		end
	end

	if self.Aiming then
		if self.current_shoulder == "Right" then
			self:_playAnim("Aim")
		else
			self:_playAnim("Aim_Left")
		end
	else
		self:_playAnim("Hold")
	end
end

-- // Input

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

-- Called by BaseTool when Current_Shoulder attribute changes.
-- Only swaps the base-layer aim tracks - never touches layer 1 or 2.
function PrinceRifle:_onShoulderChanged()
	if not self.Aiming or self.Reloading then return end

	local anims = self.RegisteredAnimations
	if self.current_shoulder == "Right" then
		if anims.Aim_Left.IsPlaying then anims.Aim_Left:Stop() end
		if not anims.Aim.IsPlaying then anims.Aim:Play() end
	else
		if anims.Aim.IsPlaying then anims.Aim:Stop() end
		if not anims.Aim_Left.IsPlaying then anims.Aim_Left:Play() end
	end
end

-- // Tool Actions

function PrinceRifle:set_alt()
	if self.Alting or self.Reloading or self.Firing or self.Cycling then return end
	self.Alting = true

	if self.Alt_Mode then
		self:_playAnim("Alt_Mode_Off").Stopped:Wait()
		self.Alt_Mode = false
		self:notify("Firemode switched to Single Fire")
	else
		self:_playAnim("Alt_Mode_On").Stopped:Wait()
		self.Alt_Mode = true
		self:notify("Firemode switched to Repeating Fire")
	end

	self.Alting = false
	self:_restoreBase()
end

-- Cleanly exits aim; use for reload/unequip, not for normal RMB toggle.
function PrinceRifle:end_aiming()
	self.Aiming = false
	self:_stopAimTracking()

	local aimAnim = self.RegisteredAnimations.Aim
	if aimAnim.IsPlaying then
		aimAnim.TimePosition = 1
		aimAnim:AdjustSpeed(-1)
		aimAnim.Stopped:Once(function()
			aimAnim:AdjustSpeed(1)
		end)
	end

	local aimLeftAnim = self.RegisteredAnimations.Aim_Left
	if aimLeftAnim.IsPlaying then
		aimLeftAnim:Stop()
	end

	if not self.Cycling and not self.Reloading then
		self:_playAnim("Hold")
	end

	game.Players.LocalPlayer.Character:SetAttribute("Aiming", false)
end

function PrinceRifle:aim()
	if self:_if_sprinting() then return end
	if self.Reloading then return end

	if not self.Aiming then
		self.Aiming = true
		self:_startAimTracking()
		self:_stopLayer(0)

		if self.current_shoulder == "Right" then
			self:_playAnim("Aim")
		else
			self:_playAnim("Aim_Left")
		end

		game.Players.LocalPlayer.Character:SetAttribute("Aiming", true)
	else
		self:end_aiming()
	end
end

-- Bolt cycle: layer-1 action that plays over the base aim/hold track.
function PrinceRifle:cycle()
	if self.Cycling then return end
	self.Cycling = true

	self:_playAnim("Cycle").Stopped:Wait()

	task.wait(CYCLE_REST_TIME)
	self.Cycled  = true
	self.Cycling = false

	self:_restoreBase()
end

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

	if self:_if_sprinting() then
		self.Firing = false
		return
	end

	local camera = workspace.CurrentCamera
	self.Caster:Fire(muzzle.Position, camera.CFrame.LookVector.Unit, 1000, self.CasterBehavior)

	local fireTrack: AnimationTrack
	if self.current_shoulder == "Right" then
		fireTrack = self:_playAnim("Fire")
	else
		fireTrack = self:_playAnim("Fire_Left")
	end

	self.Cycled   = false
	self.Capacity -= 1

	Util.applyRecoil(self.recoil, self.recoil_count, 10, false)

	fireTrack.Stopped:Once(function()
		self:_restoreBase()
	end)
	
	self:emit_effect(muzzle_flash, {"smoke_medium"}, game.Players.LocalPlayer.Character.CharacterData.Equipment.PrinceRifle.PrinceRifle_Muzzle, 1, false)
	print("Fire emit")	
		
	task.wait(FIRE_RATE)
	self.Firing = false

	if self.Alt_Mode then
		self:_alt_reload()
	end
end

-- Alt reload: layer-2 takeover just for the lever-action slap animation.
function PrinceRifle:_alt_reload()
	self:_playAnim("Reload_Alt").Stopped:Wait()
	self.Cycled = true
	self.Capacity += 1
	self:_restoreBase()
end

function PrinceRifle:Reload()
	if self.Reloading then return end
	if self.Capacity >= self.Max_Capacity then return end

	if self.Aiming then
		self.Aiming = false
		self:_stopAimTracking()
		game.Players.LocalPlayer.Character:SetAttribute("Aiming", false)
	end

	self:_stopLayer(2)
	self.Reloading        = true
	self._reloadCancelled = false

	if self.Capacity == 0 then
		self:_playAnim("Reload_Empty").Stopped:Wait()
	else
		self:_playAnim("Reload_Start").Stopped:Wait()
	end

	while self.Capacity < self.Max_Capacity and not self._reloadCancelled do
		self:_playAnim("Reload_Loop").Stopped:Wait()
		if self._reloadCancelled then break end

		self.Capacity += 1

		if not self.Cycled then
			self:cycle()
		end
	end

	if not self._reloadCancelled then
		self:_playAnim("Reload_End").Stopped:Wait()
	else
		self:_stopLayer(2)
	end

	self.Reloading        = false
	self._reloadCancelled = false

	self:_restoreBase()
end

function PrinceRifle:activate()
	if not self.actual_model then return end
	if self.Firing or self.Cycling or self.Reloading then return end

	if not self.Cycled then
		task.spawn(function()
			self:cycle()
		end)
		return
	end

	if not self.Aiming then return end

	task.spawn(function()
		self:fire()
	end)
end

-- // BaseTool Hooks

function PrinceRifle:_on_equip()
	self:_cacheMotor6D()
	game.Players.LocalPlayer.Character:SetAttribute("Sprint_Animation", "PrinceRifle")

	for _, animation: AnimationTrack in pairs(self.RegisteredAnimations) do
		if not animation:IsA("AnimationTrack") then continue end

		animation.KeyframeReached:Connect(function(keyframeName)
			local rightArm = game.Players.LocalPlayer.Character:FindFirstChild("Right Arm")
			if not rightArm then return end

			local round = rightArm:FindFirstChild(self.Round.Name)
			if not round then return end

			if keyframeName == "vfx_hand_shell_visible" then
				round.Transparency = 0
			elseif keyframeName == "vfx_hand_shell_invisible" then
				round.Transparency = 1
			end
		end)
	end
end

function PrinceRifle:_on_unequip()
	self._reloadCancelled = true
	self:_stopLayer(2)
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
	BaseTool.destroy(self)
end

return PrinceRifle
