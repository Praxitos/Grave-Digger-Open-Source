--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.BaseTool)

local Holster_Folder = ReplicatedStorage.Shared.Assets.Holsters:FindFirstChild("Tool Holsters")

local Pickaxe = {}
Pickaxe.__index = Pickaxe
setmetatable(Pickaxe, { __index = BaseTool })

export type Pickaxe = typeof(setmetatable({} :: {
	className: "Pickaxe",
	name: string,
	holster_reference: Instance?,
	tool: Tool?
}, {} :: typeof(Pickaxe)))

function Pickaxe.new(PickaxeCreateInfo: Types.BaseToolCreateInfo): Pickaxe
	local self = setmetatable({}, Pickaxe)

	self.className = "Pickaxe"
	self.name = PickaxeCreateInfo.name
	self.holster_reference = Holster_Folder and Holster_Folder:FindFirstChild("PickaxeHolster")

	return self
end


-- called when the item enters the inventory
function Pickaxe:on_give(tool: Tool)
	self.tool = tool
	print("Pickaxe received")
end


-- called by your custom inventory system
function Pickaxe:equip()
	print("Pickaxe equipped")

	-- example
	if self.tool then
		self.tool.Parent = game.Players.LocalPlayer.Character
	end
end


function Pickaxe:unequip()
	print("Pickaxe unequipped")

	if self.tool then
		self.tool.Parent = game.Players.LocalPlayer.Backpack
	end
end


function Pickaxe:activate()
	print("Pickaxe activated")
end


return Pickaxe