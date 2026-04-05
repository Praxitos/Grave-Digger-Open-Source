--!strict
--!native
--!optimize 2

-- GraceRevolver - single-action revolver with shoulder aiming, 6-round cylinder, and manual cycling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local Types    = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.Parent.BaseTool)
local Util     = require(script.Parent.Parent.Parent.Util)

-- // Asset References

local Assets         = ReplicatedStorage.Shared.Assets
local Holster_Folder = Assets.Guns.Holsters:FindFirstChild("Gun Holsters")
local Tool_Folder    = Assets.Guns.ToolModels
local Anim_Folder    = Assets.Animations.Tools.Guns.GraceRevolver
local Effects_Folder = Assets.Guns.Effects.Shooting

local muzzle_flash = Effects_Folder.Muzzle_Flash

-- // Tuning

local FIRE_RATE = 0.25

-- // Animation Priority Layers
--
--  LAYER 0 - base idle/aim:  Held, Aim, Aim_Left
--  LAYER 1 - action overlay: Fire, Fire_Left, Fire_Empty, Fire_Empty_Left, Short, Short_Alt, Spin, Spin_Start
--  LAYER 2 - full takeover:  Draw, Unequip, Check, Reload_Start, Reload_Loop, Reload_End, Melee1, Melee2

local ANIM_LAYER: {[string]: number} = {
	Held            = 0,
	Aim             = 0,
	Aim_Left        = 0,

	Fire            = 1,
	Fire_Left       = 1,
	Fire_Empty      = 1,
	Fire_Empty_Left = 1,
	Short           = 1,
	Short_Alt       = 1,
	Spin            = 1,
	Spin_Start      = 1,

	Draw         = 2,
	Unequip      = 2,
	Check        = 2,
	Melee1       = 2,
	Melee2       = 2,
	Reload_Start = 2,
	Reload_Loop  = 2,
	Reload_End   = 2,
}

-- // Class

local GraceRevolver = {}
GraceRevolver.__index = GraceRevolver
setmetatable(GraceRevolver, { __index = BaseTool })

export type GraceRevolver = typeof(setmetatable({} :: {
	className:   "GraceRevolver",
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
	Firing:    boolean,
	Reloading: boolean,
	Spinning:  boolean,

	_reloadCancelled: boolean,
	_spinCancelled:   boolean,

	current_shoulder: string,

	Caster:         any,
	CasterBehavior: any,

	motor_6d:       Motor6D?,
	_motorOriginal: { C0: CFrame, C1: CFrame, Part0: BasePart?, Part1: BasePart? }?,

	_inputBeganConn: RBXScriptConnection?,
	_inputEndedConn: RBXScriptConnection?,
}, {} :: typeof(GraceRevolver)))

-- // Constructor

function GraceRevolver.new(info: Types.BaseToolCreateInfo): GraceRevolver
	local self = setmetatable(BaseTool.new(info), GraceRevolver)

	self.className   = "GraceRevolver"
	self.item_image  = "rbxassetid://17601078078"
	self.Designation = "Secondary"

	self.holster_reference = Holster_Folder and Holster_Folder:FindFirstChild("GraceRevolverHolster")
	self.model_reference   = Tool_Folder:FindFirstChild("GraceRevolver")

	self.Round = game.ReplicatedStorage.Shared.Assets.Guns.Rounds.GraceRevolver_Round

	self.motor_6d_data = {
		Parent = "Right Arm",
		Part0  = "Right Arm",
		Part1  = self.model_reference and self.model_reference:FindFirstChild("GraceRevolver_Middle"),
		C0     = CFrame.new(-0.258, -1.438, -0.506)
			* CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
	}

	self.animations = {
		Held    = Anim_Folder.GraceRevolver_Held,
		Draw    = Anim_Folder.GraceRevolver_Draw,
		Unequip = Anim_Folder.GraceRevolver_Unequip,

		Aim      = Anim_Folder.GraceRevolver_Aim,
		Aim_Left = Anim_Folder.GraceRevolver_Aim_left,

		Fire            = Anim_Folder.GraceRevolver_Fire,
		Fire_Left       = Anim_Folder.GraceRevolver_Fire_Left,
		Fire_Empty      = Anim_Folder.GraceRevolver_Fire_Empty,
		Fire_Empty_Left = Anim_Folder.GraceRevolver_Fire_Empty_Left,

		Short     = Anim_Folder.GraceRevolver_Short,
		Short_Alt = Anim_Folder.GraceRevolver_Short_alt,

		Spin       = Anim_Folder.GraceRevolver_Spin,
		Spin_Start = Anim_Folder.GraceRevolver_Spin_start,

		Reload_Start = Anim_Folder.GraceRevolver_Reload_start,
		Reload_Loop  = Anim_Folder.GraceRevolver_Reload_loop,
		Reload_End   = Anim_Folder.GraceRevolver_Reload_end,

		Check  = Anim_Folder.GraceRevolver_Check,
		Melee1 = Anim_Folder.GraceRevolver_Melee1,
		Melee2 = Anim_Folder.GraceRevolver_Melee2,
	}

	self.damage       = 25
	self.Max_Capacity = 6
	self.Capacity     = 6
	self.Ammo_Type    = ".45 Lead"
	self.recoil       = 8
	self.recoil_count = 5
	self.Penetration_Level       = 1
	self.Armor_Penetration_Level = 2

	self.unequip_wait     = false
	self.Aiming           = false
	self.Firing           = false
	self.Reloading        = false
	self.Spinning         = false
	self._reloadCancelled = false
	self._spinCancelled   = false

	self.Caster, self.CasterBehavior = Util.setupFastCast({
		bulletTemplate  = FxFolder.Bullet,
		bulletContainer = workspace.Game_Details.Effects.Bullets,
		onHit           = function(cast, result, velocity)
			self:_onBulletHit(cast, result, velocity, self.Penetration_Level)
		end,
	})

	self:_initShoulderTracking()

	return self
end

-- // Internal: is any exclusive action currently running?

function GraceRevolver:_isBusy(): boolean
	return self.Firing or self.Reloading or self.Spinning
end

-- // Animation Layer System

function GraceRevolver:_playAnim(name: string): AnimationTrack
	local anims = self.RegisteredAnimations
	local track = anims[name]
	assert(track, "GraceRevolver: unknown animation '" .. tostring(name) .. "'")

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

function GraceRevolver:_stopLayer(maxLayer: number)
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

-- Restores the correct base-layer track. Never runs during a busy action
-- or while any layer >= 1 track is still playing.
function GraceRevolver:_restoreBase()
	local anims = self.RegisteredAnimations
	if not anims then return end
	if self:_isBusy() then return end

	for trackName, layer in pairs(ANIM_LAYER) do
		if layer >= 1 and anims[trackName] and anims[trackName].IsPlaying then
			return
		end
	end

	-- Stop whichever base tracks shouldn't be playing before starting the right one,
	-- so they never blend together.
	if self.Aiming then
		if self.current_shoulder == "Right" then
			if anims.Aim_Left and anims.Aim_Left.IsPlaying then anims.Aim_Left:Stop() end
			if anims.Held     and anims.Held.IsPlaying     then anims.Held:Stop()     end
			if not anims.Aim.IsPlaying then self:_playAnim("Aim") end
		else
			if anims.Aim  and anims.Aim.IsPlaying  then anims.Aim:Stop()  end
			if anims.Held and anims.Held.IsPlaying  then anims.Held:Stop() end
			if not anims.Aim_Left.IsPlaying then self:_playAnim("Aim_Left") end
		end
	else
		if anims.Aim     and anims.Aim.IsPlaying     then anims.Aim:Stop()     end
		if anims.Aim_Left and anims.Aim_Left.IsPlaying then anims.Aim_Left:Stop() end
		if not anims.Held.IsPlaying then self:_playAnim("Held") end
	end
end

function GraceRevolver:_restoreBaseDeferred()
	task.defer(function()
		self:_restoreBase()
	end)
end

-- // Input

function GraceRevolver:_connectInput()
	self._inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:aim()
		elseif input.KeyCode == Enum.KeyCode.R then
			self:Reload()
		elseif input.KeyCode == Enum.KeyCode.F then
			task.spawn(function() self:spin() end)
		elseif input.KeyCode == Enum.KeyCode.T then
			self:ammo_check()
		end
	end)

	self._inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:end_aiming()
		end
	end)
end

function GraceRevolver:_disconnectInput()
	if self._inputBeganConn then self._inputBeganConn:Disconnect(); self._inputBeganConn = nil end
	if self._inputEndedConn then self._inputEndedConn:Disconnect(); self._inputEndedConn = nil end
end

-- // Shoulder

-- Guards every busy state. Deferred to match BaseTool's one-frame C0 re-cache
-- so the aim track swap never lands on a stale shoulder origin.
function GraceRevolver:_onShoulderChanged()
	if self:_isBusy() then return end
	if not self.Aiming then return end

	task.defer(function()
		if self:_isBusy() then return end
		if not self.Aiming then return end
		self:_restoreBase()
	end)
end

-- // Tool Actions

-- Cleanly exits aim. Explicitly stops Held so it doesn't bleed into the
-- reversed Aim playback when called from ammo_check or reload.
function GraceRevolver:end_aiming()
	self.Aiming = false
	self:_stopAimTracking()

	local anims = self.RegisteredAnimations

	-- Stop Held immediately — it should not be playing during aim exit.
	if anims.Held and anims.Held.IsPlaying then
		anims.Held:Stop()
	end

	local aimAnim = anims.Aim
	if aimAnim and aimAnim.IsPlaying then
		aimAnim.TimePosition = 1
		aimAnim:AdjustSpeed(-1)
		aimAnim.Stopped:Once(function()
			aimAnim:AdjustSpeed(1)
		end)
	end

	local aimLeftAnim = anims.Aim_Left
	if aimLeftAnim and aimLeftAnim.IsPlaying then
		aimLeftAnim:Stop()
	end

	self:_stopAllExcept()

	game.Players.LocalPlayer.Character:SetAttribute("Aiming", false)
end

function GraceRevolver:aim()
	if self:_isBusy() then return end
	if self:_if_sprinting() then return end

	if not self.Aiming then
		self.Aiming = true
		self:_startAimTracking()

		-- Stop Held before playing aim so they don't blend.
		local anims = self.RegisteredAnimations
		self:_stopAllExcept()

		if self.current_shoulder == "Right" then
			self:_playAnim("Aim")
		else
			self:_playAnim("Aim_Left")
		end

		game.Players.LocalPlayer.Character:SetAttribute("Aiming", true)
	end
end

function GraceRevolver:spin()
	if self:_isBusy() then return end
	self.Spinning       = true
	self._spinCancelled = false

	self:_playAnim("Spin_Start").Stopped:Wait()

	if self._spinCancelled then
		self.Spinning       = false
		self._spinCancelled = false
		self:_restoreBaseDeferred()
		return
	end

	self:_playAnim("Spin")
	self.RegisteredAnimations.Spin.Stopped:Wait()

	self.Spinning       = false
	self._spinCancelled = false
	self:_restoreBaseDeferred()
end

function GraceRevolver:_cancelSpin()
	self._spinCancelled = true
	local anims = self.RegisteredAnimations
	if not anims then return end
	if anims.Spin       and anims.Spin.IsPlaying       then anims.Spin:Stop()       end
	if anims.Spin_Start and anims.Spin_Start.IsPlaying then anims.Spin_Start:Stop() end
end

function GraceRevolver:fire()
	if self.Firing then return end
	self.Firing = true

	if self.Spinning then
		self:_cancelSpin()
	end

	if self.Capacity <= 0 then
		if self.current_shoulder == "Right" then
			self:_playAnim("Fire_Empty").Stopped:Wait()
		else
			self:_playAnim("Fire_Empty_Left").Stopped:Wait()
		end
		self.Firing = false
		self:_restoreBaseDeferred()
		return
	end

	local muzzle = self.actual_model and self.actual_model:FindFirstChild("GraceRevolver_Muzzle")
	if not muzzle then
		self.Firing = false
		return
	end

	if self:_if_sprinting() then
		self.Firing = false
		return
	end

	local camera = workspace.CurrentCamera
	self.Caster:Fire(muzzle.Position, camera.CFrame.LookVector.Unit, 800, self.CasterBehavior)

	local fireTrack: AnimationTrack
	if self.current_shoulder == "Right" then
		fireTrack = self:_playAnim("Fire")
	else
		fireTrack = self:_playAnim("Fire_Left")
	end

	self.Capacity -= 1
	Util.applyRecoil(self.recoil, self.recoil_count, 10, false)

	-- Only restore if nothing else has taken over by the time fire ends.
	fireTrack.Stopped:Once(function()
		if not self.Reloading and not self.Spinning then
			self:_restoreBaseDeferred()
		end
	end)

	self:emit_effect(
		muzzle_flash,
		{"smoke_medium"},
		game.Players.LocalPlayer.Character.CharacterData.Equipment.GraceRevolver.GraceRevolver_Muzzle,
		1,
		false
	)

	task.wait(FIRE_RATE)
	self.Firing = false
end

function GraceRevolver:Reload()
	if self.Reloading then return end
	if self.Capacity >= self.Max_Capacity then return end

	if self.Spinning then
		self:_cancelSpin()
	end

	if self.Aiming then
		self:end_aiming()
	end

	self:_stopLayer(2)
	self.Reloading        = true
	self._reloadCancelled = false

	self:_playAnim("Reload_Start").Stopped:Wait()

	while self.Capacity < self.Max_Capacity and not self._reloadCancelled do
		self:_playAnim("Reload_Loop").Stopped:Wait()
		if self._reloadCancelled then break end
		self.Capacity += 1
	end

	if not self._reloadCancelled then
		self:_playAnim("Reload_End").Stopped:Wait()
	else
		if self.RegisteredAnimations.Reload_Loop.IsPlaying  then self.RegisteredAnimations.Reload_Loop:Stop()  end
		if self.RegisteredAnimations.Reload_Start.IsPlaying then self.RegisteredAnimations.Reload_Start:Stop() end
	end

	self.Reloading        = false
	self._reloadCancelled = false

	self:_restoreBaseDeferred()
end

function GraceRevolver:activate()
	if not self.actual_model then return end
	if self.Firing or self.Reloading then return end
	if not self.Aiming then return end

	task.spawn(function()
		self:fire()
	end)
end

-- // BaseTool Hooks

function GraceRevolver:_on_equip()
	self:_cacheMotor6D()
	self:_connectInput()
	self:_initShoulderTracking()
	game.Players.LocalPlayer.Character:SetAttribute("Sprint_Animation", "GraceRevolver")
	
	self:_playAnim("Held")
end

function GraceRevolver:_on_unequip()
	self._reloadCancelled = true
	self:_disconnectInput()
	self:_stopShoulderTracking()
	self:_cancelSpin()
	self:_stopLayer(2)
	self:_stopAimTracking()
	self:_resetMotor6D()

	self.Aiming    = false
	self.Firing    = false
	self.Reloading = false
	self.Spinning  = false

	local char = game.Players.LocalPlayer.Character
	if char then
		char:SetAttribute("Aiming", false)
		char:SetAttribute("Sprint_Animation", nil)
	end
end

-- // Cleanup

function GraceRevolver:Destroy()
	self:_disconnectInput()
	BaseTool.destroy(self)
end


-- // Additional Variables to be used by instances unrequiring a class
GraceRevolver.Tool_Image = "rbxassetid://17601078078"
GraceRevolver.Medal_Cost = 1
GraceRevolver.Weight = 1

return GraceRevolver