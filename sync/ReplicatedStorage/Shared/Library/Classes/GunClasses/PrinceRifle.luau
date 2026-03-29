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
local Effects_Folder = Assets.Guns.Effects.Shooting

local muzzle_flash = Effects_Folder.Muzzle_Flash

-- // Tuning

local CYCLE_REST_TIME = 0.15
local FIRE_RATE       = 0.3

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

	self.unequip_wait     = true
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

	return self
end

-- // Internal: is any action currently running?

-- Returns true if any exclusive action is in flight.
-- Used to gate _restoreBase so it never steps on an active coroutine.
function PrinceRifle:_isBusy(): boolean
	return self.Firing or self.Cycling or self.Reloading or self.Alting
end

-- // Base animation restore

-- Plays whichever layer-0 track is correct for current state.
-- ONLY call this when you are certain no other action is running.
function PrinceRifle:_restoreBase()
	if self:_isBusy() then return end
	if not self.RegisteredAnimations then return end

	local anims = self.RegisteredAnimations

	-- Stop both aim tracks cleanly before replaying the correct one,
	-- so we never have two layer-0 tracks blending at once.
	if self.Aiming then
		if self.current_shoulder == "Right" then
			if anims.Aim_Left and anims.Aim_Left.IsPlaying then
				anims.Aim_Left:Stop()
			end
			if anims.Aim and not anims.Aim.IsPlaying then
				anims.Aim:Play()
			end
		else
			if anims.Aim and anims.Aim.IsPlaying then
				anims.Aim:Stop()
			end
			if anims.Aim_Left and not anims.Aim_Left.IsPlaying then
				anims.Aim_Left:Play()
			end
		end
	else
		if anims.Aim     and anims.Aim.IsPlaying     then anims.Aim:Stop()     end
		if anims.Aim_Left and anims.Aim_Left.IsPlaying then anims.Aim_Left:Stop() end
		if anims.Hold    and not anims.Hold.IsPlaying then anims.Hold:Play()   end
	end
end

-- // Input

function PrinceRifle:_connectInput()
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
			self:end_aiming()
		end
	end)
end

function PrinceRifle:_disconnectInput()
	if self._inputBeganConn then self._inputBeganConn:Disconnect(); self._inputBeganConn = nil end
	if self._inputEndedConn then self._inputEndedConn:Disconnect(); self._inputEndedConn = nil end
end

-- // Shoulder

-- Called by BaseTool when Current_Shoulder attribute changes.
-- Guards every busy state so it never races with an in-flight action.
-- The deferred C0 re-cache in BaseTool._initShoulderTracking means
-- _leftShoulderC0/_rightShoulderC0 will be stale for exactly one frame
-- after a swap — we must not let _restoreBase kick off a new animation
-- during that window or the lerp loop will snap to the wrong origin.
function PrinceRifle:_onShoulderChanged()
	if self:_isBusy() then
		-- An action is running; it will call _restoreBase when it finishes,
		-- which will pick up the new shoulder value at that point.
		return
	end
	if not self.Aiming then return end

	-- Use task.defer to match the same-frame re-cache defer in BaseTool,
	-- so our animation swap lands AFTER the new C0 is committed.
	task.defer(function()
		-- Re-check busy inside the defer; something may have started
		-- in the one frame gap.
		if self:_isBusy() then return end
		if not self.Aiming then return end
		self:_restoreBase()
	end)
end

-- // Tool Actions

function PrinceRifle:set_alt()
	if self:_isBusy() then return end
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
	self:_restoreBase()
end

-- Cleanly exits aim; use for reload/unequip, not for normal RMB toggle.
function PrinceRifle:end_aiming()
	self.Aiming = false
	self:_stopAimTracking()
	local anims = self.RegisteredAnimations
	if not anims then return end

	-- Reverse-play Aim back to its start frame, then stop.
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

	-- Only restore Hold if nothing else is running.
	if not self:_isBusy() then
		if anims.Hold and not anims.Hold.IsPlaying then
			anims.Hold:Play()
		end
	end

	game.Players.LocalPlayer.Character:SetAttribute("Aiming", false)
end

function PrinceRifle:aim()
	if self:_if_sprinting() then return end

	if not self.Aiming then
		if self:_isBusy() then return end
		self.Aiming = true
		self:_startAimTracking()

		-- Stop Hold before playing aim so they don't blend.
		local anims = self.RegisteredAnimations
		if anims and anims.Hold and anims.Hold.IsPlaying then
			anims.Hold:Stop()
		end

		if self.current_shoulder == "Right" then
			if anims then anims.Aim:Play() end
		else
			if anims then anims.Aim_Left:Play() end
		end

		game.Players.LocalPlayer.Character:SetAttribute("Aiming", true)
	end
end

-- Bolt cycle: plays over the base aim/hold track.
function PrinceRifle:cycle()
	if self.Cycling then return end
	self.Cycling = true

	-- Stop only the overlay tracks (fire anims), not the base aim/hold.
	-- This prevents the rifle model from jumping when cycling after a shot.
	local anims = self.RegisteredAnimations
	if anims then
		if anims.Fire      and anims.Fire.IsPlaying      then anims.Fire:Stop()      end
		if anims.Fire_Left and anims.Fire_Left.IsPlaying then anims.Fire_Left:Stop() end
	end

	anims.Cycle:Play()
	anims.Cycle.Stopped:Wait()

	task.wait(CYCLE_REST_TIME)
	self.Cycled  = true
	self.Cycling = false

	-- _restoreBase is now safe to call: Cycling is false, and we haven't
	-- touched the base track, so if it's still playing nothing changes.
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

	local anims    = self.RegisteredAnimations
	local fireAnim = (self.current_shoulder == "Right") and anims.Fire or anims.Fire_Left

	self.Cycled   = false
	self.Capacity -= 1

	Util.applyRecoil(self.recoil, self.recoil_count, 10, false)

	fireAnim:Play()

	-- When the fire animation ends, only restore base if nothing else
	-- has taken over in the meantime (e.g. cycle was queued immediately).
	fireAnim.Stopped:Once(function()
		if not self.Cycling and not self.Reloading and not self.Alting then
			self:_restoreBase()
		end
	end)

	self:emit_effect(
		muzzle_flash,
		{"smoke_medium"},
		game.Players.LocalPlayer.Character.CharacterData.Equipment.PrinceRifle.PrinceRifle_Muzzle,
		1,
		false
	)

	task.wait(FIRE_RATE)
	self.Firing = false

	if self.Alt_Mode then
		self:_alt_reload()
	end
end

-- Alt reload: lever-action slap animation.
function PrinceRifle:_alt_reload()
	local anims = self.RegisteredAnimations
	anims.Reload_Alt:Play()
	anims.Reload_Alt.Stopped:Wait()
	self.Cycled   = true
	self.Capacity += 1
	self:_restoreBase()
end

function PrinceRifle:Reload()
	if self.Reloading then return end
	if self.Capacity >= self.Max_Capacity then return end

	if self.Aiming then
		self:end_aiming()
	end

	-- Stop everything cleanly before entering the reload coroutine.
	self:_stopAllExcept(nil)

	self.Reloading        = true
	self._reloadCancelled = false

	local anims = self.RegisteredAnimations

	if self.Capacity == 0 then
		anims.Reload_Empty:Play()
		anims.Reload_Empty.Stopped:Wait()
	else
		anims.Reload_Start:Play()
		anims.Reload_Start.Stopped:Wait()
	end

	while self.Capacity < self.Max_Capacity and not self._reloadCancelled do
		anims.Reload_Loop:Play()
		anims.Reload_Loop.Stopped:Wait()
		if self._reloadCancelled then break end

		self.Capacity += 1

		if not self.Cycled then
			-- cycle() is now safe to call inline since it only stops fire tracks.
			self:cycle()
		end
	end

	if not self._reloadCancelled then
		anims.Reload_End:Play()
		anims.Reload_End.Stopped:Wait()
	else
		-- Cancelled mid-reload: stop whatever was playing.
		if anims.Reload_Loop  and anims.Reload_Loop.IsPlaying  then anims.Reload_Loop:Stop()  end
		if anims.Reload_Start and anims.Reload_Start.IsPlaying then anims.Reload_Start:Stop() end
		if anims.Reload_Empty and anims.Reload_Empty.IsPlaying then anims.Reload_Empty:Stop() end
	end

	self.Reloading        = false
	self._reloadCancelled = false

	self:_restoreBase()
end

function PrinceRifle:activate()
	if not self.actual_model then return end
	if self.Firing or self.Cycling or self.Reloading then return end

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
	self:_connectInput()
	self:_initShoulderTracking()
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

-- // Cleanup

function PrinceRifle:Destroy()
	self:_disconnectInput()
	BaseTool.destroy(self)
end

return PrinceRifle