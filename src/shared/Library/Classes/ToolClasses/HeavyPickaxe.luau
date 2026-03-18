--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Parent.Types)
local PickaxeBase = require(script.Parent.Pickaxe)

local Holster_Folder = ReplicatedStorage.Shared.Assets.Holsters:FindFirstChild("Tool Holsters")

local HeavyPickaxe = {}
HeavyPickaxe.__index = HeavyPickaxe
setmetatable(HeavyPickaxe, { __index = PickaxeBase })

export type HeavyPickaxe = typeof(setmetatable({} :: {
	className: "HeavyPickaxe",
	name: string,
	item_image: string,
	holster_reference: Instance?,
	actual_holster: Model?,
	tool: Tool?,
	mining_power: number
}, {} :: typeof(HeavyPickaxe)))

function HeavyPickaxe.new(PickaxeCreateInfo: Types.BaseToolCreateInfo): HeavyPickaxe
	local self = setmetatable(PickaxeBase.new(PickaxeCreateInfo), HeavyPickaxe)
	self.className = "HeavyPickaxe"
	self.item_image = "rbxassetid://127069712406722" 

	self.holster_reference = Holster_Folder and Holster_Folder:FindFirstChild("HeavyPickaxeHolster")

	self.mining_power = 10 

	return self
end

return HeavyPickaxe