--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.Parent.BaseTool)

local Holster_Folder = ReplicatedStorage.Shared.Assets.Holsters:FindFirstChild("Gun Holsters")
local Tool_Folder = ReplicatedStorage.Shared.Assets.ToolModels

local GraceRevolver = {}
GraceRevolver.__index = GraceRevolver
setmetatable(GraceRevolver, { __index = BaseTool })

export type GraceRevolver = typeof(setmetatable({} :: {
	className: "GraceRevolver",
	name: string,

	item_image: string,
	Designation: string,

	holster_reference: Instance?,
	actual_holster: Model?,

	model_reference: Model?,
	actual_model: Model?,

	motor_6d_data: {
		Parent: string,
		Part0: string,
		Part1: BasePart?,
		C0: CFrame
	}?,

	animations: {[string]: Animation}?,
	RegisteredAnimations: {[string]: AnimationTrack}?,

	damage: number
}, {} :: typeof(GraceRevolver)))

function GraceRevolver.new(info: Types.BaseToolCreateInfo): GraceRevolver
	local self = setmetatable(BaseTool.new(info), GraceRevolver)

	self.className = "GraceRevolver"

	self.item_image = "rbxassetid://127069712406722"
	self.Designation = "Primary"

	self.holster_reference =
		Holster_Folder and Holster_Folder:FindFirstChild("GraceRevolverHolster")

	self.model_reference = Tool_Folder:FindFirstChild("GraceRevolver")

	self.motor_6d_data = {
		Parent = "Left Arm",
		Part0 = "Left Arm",
		Part1 = self.model_reference
			and self.model_reference:FindFirstChild("GraceRevolver_Middle"),
		C0 = CFrame.new(0.254, -1.703, -0.566)
			* CFrame.Angles(math.rad(0.979), math.rad(-90), math.rad(90))
	}

	-- optional: if you add gun animations later
	self.animations = {
		--Draw = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.GraceRevolver.GraceRevolver_Draw,
		--Hold = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.GraceRevolver.GraceRevolver_Held,
		--Unequip = ReplicatedStorage.Shared.Assets.Animations.Tools.Guns.GraceRevolver.GraceRevolver_Unequip,
	}

	self.damage = 25

	self.unequip_wait = false
	
	return self
end

-- optional hook if you need custom give logic later
function GraceRevolver:_on_give(tool: Tool, holster: Model?, model: Model?)
	
end

function GraceRevolver:activate()
	-- placeholder gun logic
	-- replace with raycast / projectile system later
	print("GraceRevolver fired")

	-- example future:
	-- raycast → detect hit → apply damage
end

return GraceRevolver