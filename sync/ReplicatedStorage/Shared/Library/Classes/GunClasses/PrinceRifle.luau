--------------------------------------------------------------------------------
-- PrinceRifle
-- Bolt-action rifle with manual cycling, shoulder-swappable aiming, and an
-- alt (repeating) fire mode that auto-cycles via lever-action animation.
--------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local Types    = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.Parent.BaseTool)
local Util     = require(script.Parent.Parent.Parent.Util)

--------------------------------------------------------------------------------
-- Asset paths
--------------------------------------------------------------------------------

local Assets        = ReplicatedStorage.Shared.Assets
local HolsterFolder = Assets.Guns.Holsters:FindFirstChild("Gun Holsters")
local ToolFolder    = Assets.Guns.ToolModels
local AnimFolder    = Assets.Animations.Tools.Guns.PrinceRifle
local FxFolder      = Assets.Guns.Effects.Shooting

local FX_MUZZLE_FLASH = FxFolder.Muzzle_Flash
local FX_WOOD_CHIPS   = FxFolder.Parent.Environment.Wood_Chips

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

local CYCLE_REST_TIME   = 0.15  -- seconds to pause after bolt cycle
local FIRE_RATE         = 0.30  -- minimum seconds between shots
local PENETRATION_RANGE = 50    -- max stud distance at which bullets can penetrate
local BULLET_SPEED      = 1000  -- studs/s

--------------------------------------------------------------------------------
-- Class
--------------------------------------------------------------------------------

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

	-- Stats
	damage:                  number,
	Max_Capacity:            number,
	Capacity:                number,
	Ammo_Type:               string,
	recoil:                  number,
	recoil_count:            number,
	Penetration_Level:       number,
	Armor_Penetration_Level: number,

	-- State flags
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

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function PrinceRifle.new(info: Types.BaseToolCreateInfo): PrinceRifle
	local self = setmetatable(BaseTool.new(info), PrinceRifle)

	-- Identity
	self.className   = "PrinceRifle"
	self.item_image  = "rbxassetid://17496049645"
	self.Designation = "Primary"

	-- References
	self.holster_reference = HolsterFolder and HolsterFolder:FindFirstChild("PrinceRifleHolster")
	self.model_reference   = ToolFolder:FindFirstChild("PrinceRifle")
	self.Round             = Assets.Guns.Rounds.PrinceRifle_Round

	-- Motor6D attachment
	self.motor_6d_data = {
		Parent = "Left Arm",
		Part0  = "Left Arm",
		Part1  = self.model_reference and self.model_reference:FindFirstChild("PrinceRifle_Middle"),
		C0     = CFrame.new(0.254, -1.703, -0.566)
			* CFrame.Angles(math.rad(0.979), math.rad(-90), math.rad(90)),
	}

	-- Animation references
	self.animations = {
		Draw    = AnimFolder.PrinceRifle_Draw,
		Hold    = AnimFolder.PrinceRifle_Held,
		Unequip = AnimFolder.PrinceRifle_Unequip,

		Aim      = AnimFolder.PrinceRifle_Aim,
		Aim_Left = AnimFolder.PrinceRifle_Aim_Left,

		Fire      = AnimFolder.PrinceRifle_Fire,
		Fire_Left = AnimFolder.PrinceRifle_Fire_Left,

		Cycle = AnimFolder.PrinceRifle_Cycle,

		Reload_Empty = AnimFolder.PrinceRifle_Reload_Empty,
		Reload_Start = AnimFolder.PrinceRifle_Reload_Start,
		Reload_Loop  = AnimFolder.PrinceRifle_Reload_Loop,
		Reload_End   = AnimFolder.PrinceRifle_Reload_End,
		Reload_Alt   = AnimFolder.PrinceRifle_Reload_Alt,

		Alt_Mode_On  = AnimFolder.PrinceRifle_Alt_Mode_On,
		Alt_Mode_Off = AnimFolder.PrinceRifle_Alt_Mode_Off,

		Check = AnimFolder.PrinceRifle_Check,
	}

	-- Weapon stats
	self.damage                  = 25
	self.Max_Capacity            = 10
	self.Capacity                = 10
	self.Ammo_Type               = "8mm Smokeless"
	self.recoil                  = 10
	self.recoil_count            = 6
	self.Penetration_Level       = 2
	self.Armor_Penetration_Level = 3

	-- State
	self.unequip_wait     = true
	self.Cycled           = true
	self.Firing           = false
	self.Cycling          = false
	self.Reloading        = false
	self.Alt_Mode         = false
	self.Alting           = false
	self._reloadCancelled = false

	-- Projectile caster
	self.Caster, self.CasterBehavior = Util.setupFastCast({
		bulletTemplate  = FxFolder.Bullet,
		bulletContainer = workspace.Game_Details.Effects.Bullets,
		onHit           = function(cast, result, velocity)
			self:_onBulletHit(cast, result, velocity)
		end,
	})

	self:_initShoulderTracking()

	return self
end

--------------------------------------------------------------------------------
-- Private: Projectile
--------------------------------------------------------------------------------

-- Handles all hit logic: surface effects, penetration check, exit decal, and
-- spawning a continuation cast through thin geometry.
function PrinceRifle:_onBulletHit(cast: any, result: RaycastResult, velocity: Vector3)
	-- Surface VFX
	if result.Material == Enum.Material.Wood then
		self:emit_effect(
			FX_WOOD_CHIPS,
			CFrame.new(result.Position, result.Position + result.Normal),
			{ "woodchip1", "woodchip2", "woodchip3" },
			result.Instance,
			20,
			false
		)
	end

	if cast.UserData.Penetrated then return end

	-- Range check: no penetration beyond PENETRATION_RANGE studs
	local muzzle = self.actual_model and self.actual_model.PrinceRifle_Muzzle
	if not muzzle or (muzzle.Position - result.Position).Magnitude > PENETRATION_RANGE then
		cast.UserData.Penetrated = true
		return
	end

	local direction = cast.UserData.Direction :: Vector3

	-- Entry decal
	self:bullet_hole(result.Position, result.Normal)

	-- Trace the exit point from the far side back toward entry
	local exitParams = RaycastParams.new()
	exitParams.FilterType = Enum.RaycastFilterType.Include
	exitParams.FilterDescendantsInstances = { result.Instance }

	local exitResult = workspace:Raycast(result.Position + direction * 100, -direction * 100, exitParams)
	if exitResult then
		self:bullet_hole(exitResult.Position, exitResult.Normal)
	end

	-- Continue cast through geometry
	cast.UserData.Penetrated = true
	local continuation = self.Caster:Fire(
		result.Position + direction * 0.2,
		direction,
		velocity.Magnitude,
		self.CasterBehavior
	)
	continuation.UserData.Direction  = direction
	continuation.UserData.Penetrated = true
end

--------------------------------------------------------------------------------
-- Private: State helpers
--------------------------------------------------------------------------------

-- Returns true while any exclusive action is in progress.
function PrinceRifle:_isBusy(): boolean
	return self.Firing or self.Cycling or self.Reloading or self.Alting
end

-- Hard-stops every registered AnimationTrack, optionally skipping one by name.
function PrinceRifle:_stopAllExcept(except: string?)
	local anims = self.RegisteredAnimations
	if not anims then return end

	for name, track in pairs(anims) do
		if name == except then continue end
		if not track:IsA("AnimationTrack") then continue end
		if track.IsPlaying then track:Stop(0) end
	end
end

-- Restores the correct idle or aim base track after an action finishes.
-- Must only be called once _isBusy() is false.
function PrinceRifle:_restoreBase()
	if self:_isBusy() then return end

	local anims = self.RegisteredAnimations
	if not anims then return end

	-- Hard-kill both aim tracks before deciding which to replay,
	-- preventing any single-frame blend between them.
	if anims.Aim      and anims.Aim.IsPlaying      then anims.Aim:Stop(0)      end
	if anims.Aim_Left and anims.Aim_Left.IsPlaying then anims.Aim_Left:Stop(0) end

	if self.Aiming then
		local aimTrack = (self.current_shoulder == "Right") and anims.Aim or anims.Aim_Left
		aimTrack:Play()
	else
		if anims.Hold and not anims.Hold.IsPlaying then
			anims.Hold:Play()
		end
	end
end

--------------------------------------------------------------------------------
-- Private: Input
--------------------------------------------------------------------------------

function PrinceRifle:_connectInput()
	self._inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:aim()
		elseif input.KeyCode == Enum.KeyCode.R then
			self:reload()
		elseif input.KeyCode == Enum.KeyCode.F then
			self:setAltMode()
		elseif input.KeyCode == Enum.KeyCode.T then
			self:ammo_check()
		end
	end)

	self._inputEndedConn = UserInputService.InputEnded:Connect(function(input, processed)
		if processed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:endAiming()
		end
	end)
end

function PrinceRifle:_disconnectInput()
	if self._inputBeganConn then
		self._inputBeganConn:Disconnect()
		self._inputBeganConn = nil
	end
	if self._inputEndedConn then
		self._inputEndedConn:Disconnect()
		self._inputEndedConn = nil
	end
end

--------------------------------------------------------------------------------
-- Private: Shoulder tracking
--------------------------------------------------------------------------------

-- Called by BaseTool when Current_Shoulder changes.
-- Resets motor6D to its canonical C0 before BaseTool's deferred re-cache fires,
-- preventing the lerp loop from compounding mid-lerp offsets as the new origin.
-- Double-defers the anim swap so both the cache commit and any lerp-reset
-- have fully settled before a new animation touches the motor.
function PrinceRifle:_onShoulderChanged()
	if self:_isBusy() then
		-- The active action will call _restoreBase on completion,
		-- picking up the new shoulder value at that point.
		return
	end

	if not self.Aiming then return end

	if self.motor_6d and self._motorOriginal then
		self.motor_6d.C0 = self._motorOriginal.C0
	end

	task.defer(function()
		task.defer(function()
			if self:_isBusy() or not self.Aiming then return end
			self:_restoreBase()
		end)
	end)
end

--------------------------------------------------------------------------------
-- Public: Actions
--------------------------------------------------------------------------------

-- Toggles between single-fire and repeating (alt) fire mode.
function PrinceRifle:setAltMode()
	if self:_isBusy() then return end
	self.Alting = true

	local anims = self.RegisteredAnimations

	if self.Alt_Mode then
		anims.Alt_Mode_Off:Play()
		anims.Alt_Mode_Off.Stopped:Wait()
		self.Alt_Mode = false
		self:notify("Firemode: Single Fire")
	else
		anims.Alt_Mode_On:Play()
		anims.Alt_Mode_On.Stopped:Wait()
		self.Alt_Mode = true
		self:notify("Firemode: Repeating Fire")
	end

	self.Alting = false
	task.defer(function() self:_restoreBase() end)
end

-- Transitions into aimed stance. Defers the anim play by one frame so the
-- animator flushes all Stop(0) calls before evaluating the first keyframe.
function PrinceRifle:aim()
	if self:_if_sprinting() then return end
	if self.Aiming or self:_isBusy() then return end

	self.Aiming = true
	self:_startAimTracking()

	local anims = self.RegisteredAnimations
	if not anims then return end

	if anims.Hold     and anims.Hold.IsPlaying     then anims.Hold:Stop(0)     end
	if anims.Aim      and anims.Aim.IsPlaying      then anims.Aim:Stop(0)      end
	if anims.Aim_Left and anims.Aim_Left.IsPlaying then anims.Aim_Left:Stop(0) end

	task.defer(function()
		if not self.Aiming then return end -- RMB released within the same frame
		local aimTrack = (self.current_shoulder == "Right") and anims.Aim or anims.Aim_Left
		aimTrack:Play()
	end)

	game.Players.LocalPlayer.Character:SetAttribute("Aiming", true)
end

-- Exits aimed stance. If Aim was playing it reverse-plays back to frame 0
-- before restoring Hold, producing a clean un-aim transition.
function PrinceRifle:endAiming()
	self.Aiming = false
	self:_stopAimTracking()

	local anims = self.RegisteredAnimations
	if not anims then return end

	-- Kill Aim_Left first so it never overlaps the Aim reverse-play.
	if anims.Aim_Left and anims.Aim_Left.IsPlaying then
		anims.Aim_Left:Stop(0)
	end

	local aimTrack = anims.Aim
	if aimTrack and aimTrack.IsPlaying then
		aimTrack.TimePosition = 1
		aimTrack:AdjustSpeed(-1)
		aimTrack.Stopped:Once(function()
			aimTrack:AdjustSpeed(1)
			-- Start Hold inside the callback so it never overlaps the
			-- reverse-play tail.
			if not self:_isBusy() and not self.Aiming then
				if anims.Hold and not anims.Hold.IsPlaying then
					anims.Hold:Play()
				end
			end
		end)
	else
		-- Aim wasn't playing (left shoulder or not yet started)
		if not self:_isBusy() then
			if anims.Hold and not anims.Hold.IsPlaying then
				anims.Hold:Play()
			end
		end
	end

	game.Players.LocalPlayer.Character:SetAttribute("Aiming", false)
end

-- Plays the bolt-cycle animation. Hard-stops ALL other tracks first so
-- nothing from the previous state bleeds into the cycle clip.
function PrinceRifle:cycle()
	if self.Cycling then return end
	self.Cycling = true

	local anims = self.RegisteredAnimations
	if not anims then
		self.Cycling = false
		return
	end

	for name, track in pairs(anims) do
		if name == "Cycle" then continue end
		if not track:IsA("AnimationTrack") then continue end
		if track.IsPlaying then track:Stop(0) end
	end

	anims.Cycle:Play()
	anims.Cycle.Stopped:Wait()

	task.wait(CYCLE_REST_TIME)

	self.Cycled  = true
	self.Cycling = false

	-- Defer one frame so any action that began exactly as Cycle ended
	-- has time to raise its busy flag before we attempt a restore.
	task.defer(function() self:_restoreBase() end)
end

-- Fires one round: spawns projectile, applies recoil, plays animation and
-- muzzle FX, then branches into alt-mode auto-cycle when enabled.
function PrinceRifle:fire()
	if self.Capacity <= 0 then
		self:reload()
		return
	end
	if self.Firing then return end
	self.Firing = true

	local muzzle = self.actual_model and self.actual_model:FindFirstChild("PrinceRifle_Muzzle")
	if not muzzle or self:_if_sprinting() then
		self.Firing = false
		return
	end

	-- Projectile
	local direction = muzzle.CFrame.LookVector.Unit
	local activeCast = self.Caster:Fire(muzzle.Position, direction, BULLET_SPEED, self.CasterBehavior)
	activeCast.UserData.Direction  = direction
	activeCast.UserData.Penetrated = false

	-- State
	self.Cycled   = false
	self.Capacity -= 1

	-- Animation
	local anims    = self.RegisteredAnimations
	local fireAnim = (self.current_shoulder == "Right") and anims.Fire or anims.Fire_Left
	fireAnim:Play()

	-- Give cycle() one deferred frame to raise Cycling = true before we
	-- decide whether to fall back to idle/aim.
	fireAnim.Stopped:Once(function()
		task.defer(function()
			if not self:_isBusy() then self:_restoreBase() end
		end)
	end)

	-- Recoil
	Util.applyRecoil(self.recoil, self.recoil_count, 10, false)

	-- Muzzle FX
	local muzzleEquipped = game.Players.LocalPlayer.Character
		.CharacterData.Equipment.PrinceRifle.PrinceRifle_Muzzle
	self:emit_effect(
		FX_MUZZLE_FLASH,
		muzzleEquipped.CFrame * CFrame.new(-0.1, 0, -2),
		{ "smoke_medium", "smoke_forward", "flash_general" },
		muzzleEquipped,
		1,
		false
	)

	task.wait(FIRE_RATE)
	self.Firing = false

	if self.Alt_Mode then
		self:_altReload()
	end
end

-- Alt-mode lever slap: plays the quick re-cock animation and adds one round.
function PrinceRifle:_altReload()
	local anims = self.RegisteredAnimations
	anims.Reload_Alt:Play()
	anims.Reload_Alt.Stopped:Wait()
	self.Cycled   = true
	self.Capacity += 1
	task.defer(function() self:_restoreBase() end)
end

-- Full tube reload. Feeds rounds one by one via Reload_Loop until full
-- or cancelled by unequip.
function PrinceRifle:reload()
	if self.Reloading then return end
	if self.Capacity >= self.Max_Capacity then return end

	if self.Aiming then self:endAiming() end

	self:_stopAllExcept(nil)
	self.Reloading        = true
	self._reloadCancelled = false

	local anims = self.RegisteredAnimations

	-- Opening animation: empty-chamber vs. mid-tube
	if self.Capacity == 0 then
		anims.Reload_Empty:Play()
		anims.Reload_Empty.Stopped:Wait()
	else
		anims.Reload_Start:Play()
		anims.Reload_Start.Stopped:Wait()
	end

	-- Feed loop
	while self.Capacity < self.Max_Capacity and not self._reloadCancelled do
		anims.Reload_Loop:Play()
		anims.Reload_Loop.Stopped:Wait()
		if self._reloadCancelled then break end

		self.Capacity += 1

		if not self.Cycled then
			self:cycle()
		end
	end

	if not self._reloadCancelled then
		anims.Reload_End:Play()
		anims.Reload_End.Stopped:Wait()
	else
		for _, name in ipairs({ "Reload_Loop", "Reload_Start", "Reload_Empty" }) do
			local track = anims[name]
			if track and track.IsPlaying then track:Stop(0) end
		end
	end

	self.Reloading        = false
	self._reloadCancelled = false

	task.defer(function() self:_restoreBase() end)
end

-- Primary activation: cycles the bolt if the action is open, otherwise fires.
function PrinceRifle:activate()
	if not self.actual_model then return end
	if self:_isBusy() then return end

	if not self.Cycled then
		task.spawn(function() self:cycle() end)
		return
	end

	if not self.Aiming then return end

	task.spawn(function() self:fire() end)
end

--------------------------------------------------------------------------------
-- BaseTool lifecycle hooks
--------------------------------------------------------------------------------

function PrinceRifle:_on_equip()
	self:_cacheMotor6D()
	self:_connectInput()
	self:_initShoulderTracking()

	local char = game.Players.LocalPlayer.Character
	char:SetAttribute("Sprint_Animation", "PrinceRifle")

	-- Keyframe-driven round visibility for eject/insert VFX
	for _, track in pairs(self.RegisteredAnimations) do
		if not track:IsA("AnimationTrack") then continue end

		track.KeyframeReached:Connect(function(keyframe)
			local rightArm = char:FindFirstChild("Right Arm")
			if not rightArm then return end

			local round = rightArm:FindFirstChild(self.Round.Name)
			if not round then return end

			if keyframe == "vfx_hand_shell_visible" then
				round.Transparency = 0
			elseif keyframe == "vfx_hand_shell_invisible" then
				round.Transparency = 1
			end
		end)
	end
end

function PrinceRifle:_on_unequip()
	self._reloadCancelled = true -- cancel any in-progress reload

	self:_disconnectInput()
	self:_stopShoulderTracking()
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

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function PrinceRifle:Destroy()
	self:_disconnectInput()
	BaseTool.destroy(self)
end

--------------------------------------------------------------------------------
-- Static metadata
--------------------------------------------------------------------------------

PrinceRifle.Tool_Image = "rbxassetid://17496049645"
PrinceRifle.Medal_Cost = 0
PrinceRifle.Weight     = 2

return PrinceRifle