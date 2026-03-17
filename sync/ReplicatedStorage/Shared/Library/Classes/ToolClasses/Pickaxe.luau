--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.BaseTool)

local Holster_Folder = ReplicatedStorage.Shared.Assets.Holsters:FindFirstChild("Tool Holsters")
local utilities_module = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("Util"))

local Pickaxe = {}
Pickaxe.__index = Pickaxe
setmetatable(Pickaxe, { __index = BaseTool })

export type Pickaxe = typeof(setmetatable({} :: {
	className: "Pickaxe",
	name: string,
	item_image: string,
	holster_reference: Instance?,
	tool: Tool?
}, {} :: typeof(Pickaxe)))

function Pickaxe.new(PickaxeCreateInfo: Types.BaseToolCreateInfo): Pickaxe
	local self = setmetatable({}, Pickaxe)

	self.className = "Pickaxe"
	self.name = PickaxeCreateInfo.name
	self.item_image = "rbxassetid://127069712406722"
	self.Designation = "Mining"
	self.holster_reference = Holster_Folder and Holster_Folder:FindFirstChild("PickaxeHolster")
	self.actual_holster = nil

	return self
end


-- called when the item enters the inventory
function Pickaxe:on_give(tool: Tool, holster: Model)
	self.tool = tool
	self.actual_holster = utilities_module.reverse_search_holster(game.Players.LocalPlayer, self.holster_reference.Name)
	print("Pickaxe received and set actual_holster to:", self.actual_holster)
end


-- called by your custom inventory system
function Pickaxe:equip()
	self.tool.Parent = game.Players.LocalPlayer.Character
	utilities_module.hide_holster(game.Players.LocalPlayer ,self.actual_holster)
	print("Pickaxe received and hid holster.")	
end


function Pickaxe:unequip()
	self.tool.Parent = game.Players.LocalPlayer.Backpack
	utilities_module.show_holster(game.Players.LocalPlayer, self.actual_holster)

	print("Pickaxe received and showed holster")
end


function Pickaxe:activate()
	
end


return Pickaxe