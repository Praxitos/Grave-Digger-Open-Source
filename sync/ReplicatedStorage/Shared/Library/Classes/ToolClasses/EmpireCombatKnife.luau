--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.Parent.BaseTool)

local Holster_Folder = ReplicatedStorage.Shared.Assets.Guns.Holsters:FindFirstChild("Tool Holsters")
local Tool_Folder = ReplicatedStorage.Shared.Assets.Guns.ToolModels
local Animations_Folder = ReplicatedStorage.Shared.Assets.Animations

local utilities_module = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("Util"))

local LOCAL_PLAYER = Players.LocalPlayer

local EmpireCombatKnife = {}
EmpireCombatKnife.__index = EmpireCombatKnife
setmetatable(EmpireCombatKnife, { __index = BaseTool })

export type EmpireCombatKnife = typeof(setmetatable({} :: {
	className: "EmpireCombatKnife",
	name: string,
	item_image: string,
	Designation: string,
	holster_reference: Instance?,
	actual_holster: Model?,
	tool: Tool?,
	model_reference: Model?,
	actual_model: Model?,
	motor_6d_data: {
		Parent: string,
		Part0: string,
		Part1: string,
		C0: CFrame
	},
	animations: {[string]: Animation},
	RegisteredAnimations: {[string]: AnimationTrack}?,

	_activationConnection: RBXScriptConnection?
}, {} :: typeof(EmpireCombatKnife)))

function EmpireCombatKnife.new(EmpireCombatKnifeCreateInfo: Types.BaseToolCreateInfo): EmpireCombatKnife
	local self = setmetatable(BaseTool.new(EmpireCombatKnifeCreateInfo), EmpireCombatKnife)

	self.className = "EmpireCombatKnife"
	self.item_image = "rbxassetid://127069712406722"
	self.Designation = "Melee"

	self.holster_reference = Holster_Folder and Holster_Folder:FindFirstChild("EmpireCombatKnifeHolster")
	self.actual_holster = nil

	--self.model_reference = Tool_Folder:FindFirstChild("EmpireCombatKnife")
	--self.actual_model = nil

	--self.motor_6d_data = {
		--Parent = "Right Arm",
		--Part0 = "Right Arm",
		--Part1 = self.model_reference.EmpireCombatKnife_Middle,
		--C0 = CFrame.new(-0.184, -0.939, 0.183) * CFrame.Angles(0.005, math.rad(-90), math.rad(90))
	--}

	self.animations = {
		--Draw = Animations_Folder.Tools.EmpireCombatKnifes.Regular.EmpireCombatKnife_Draw,
		--Hold = Animations_Folder.Tools.EmpireCombatKnifes.Regular.EmpireCombatKnife_Hold,
		--Melee1 = Animations_Folder.Tools.EmpireCombatKnifes.Regular.EmpireCombatKnife_Melee1,
		--Melee2 = Animations_Folder.Tools.EmpireCombatKnifes.Regular.EmpireCombatKnife_Melee2,
		--Mine = Animations_Folder.Tools.EmpireCombatKnifes.Regular.EmpireCombatKnife_Mine,
		--Unequip = Animations_Folder.Tools.EmpireCombatKnifes.Regular.EmpireCombatKnife_Unequip
	}

	self._activationConnection = nil

	return self
end

function EmpireCombatKnife:on_give(tool: Tool, holster: Model?, model: Model?)
end

function EmpireCombatKnife:equip()
end

function EmpireCombatKnife:unequip()
end

function EmpireCombatKnife:activate()
end

return EmpireCombatKnife