--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Types)
local utilities_module = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("Util")
)

local LOCAL_PLAYER = Players.LocalPlayer

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

	-- internal
	_activationConnection: RBXScriptConnection?
}, {} :: typeof(BaseTool)))

-- constructor
function BaseTool.new(BaseToolCreateInfo: Types.BaseToolCreateInfo): BaseTool
	local self = setmetatable({}, BaseTool)

	self.className = "BaseTool"
	self.name = BaseToolCreateInfo.name

	self.tool = nil
	self.actual_model = nil
	self.actual_holster = nil
	self.RegisteredAnimations = nil

	self._activationConnection = nil

	return self
end

-- lifecycle: called when tool is given
function BaseTool:on_give(tool: Tool, holster: Model?, model: Model?)
	self.tool = tool

	-- animations (generic)
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

-- equip logic (shared)
function BaseTool:equip()
	if not self.tool then return end

	local character = LOCAL_PLAYER.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid:EquipTool(self.tool)

	-- play animations if defined
	if self.RegisteredAnimations then
		local draw = self.RegisteredAnimations.Draw
		local hold = self.RegisteredAnimations.Hold

		if draw then draw:Play() end
		if hold then hold:Play() end
	end

	-- hide holster
	if self.actual_holster then
		utilities_module.hide_holster(LOCAL_PLAYER, self.actual_holster)
	end

	-- optional subclass hook
	if self._on_equip then
		self:_on_equip()
	end
end

-- unequip logic (shared)
function BaseTool:unequip()
	if not self.tool then return end

	local character = LOCAL_PLAYER.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if self.RegisteredAnimations and self.RegisteredAnimations.Unequip then
		self.RegisteredAnimations.Unequip:Play()
		self.RegisteredAnimations.Unequip.Stopped:Wait()
	end

	humanoid:UnequipTools()

	-- stop all animations
	if self.RegisteredAnimations then
		for _, anim in pairs(self.RegisteredAnimations) do
			anim:Stop()
		end
	end

	-- optional subclass hook
	if self._on_unequip then
		self:_on_unequip()
	end
end

-- activation (must be overridden)
function BaseTool:activate()
	error(self.className .. " missing activate()")
end

-- cleanup (important for memory leaks)
function BaseTool:destroy()
	if self._activationConnection then
		self._activationConnection:Disconnect()
		self._activationConnection = nil
	end

	if self.actual_model then
		self.actual_model:Destroy()
		self.actual_model = nil
	end
end

return BaseTool