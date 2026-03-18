--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Parent.Types)
local BaseTool = require(script.Parent.BaseTool)

local Holster_Folder = ReplicatedStorage.Shared.Assets.Holsters:FindFirstChild("Tool Holsters")
local utilities_module = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("Util"))
local delete_terrain: RemoteEvent = ReplicatedStorage.Shared.Library.Events.Terrain_Communication.Delete_Terrain

local LOCAL_PLAYER = Players.LocalPlayer

local Pickaxe = {}
Pickaxe.__index = Pickaxe
setmetatable(Pickaxe, { __index = BaseTool })

export type Pickaxe = typeof(setmetatable({} :: {
	className: "Pickaxe",
	name: string,
	item_image: string,
	Designation: string,
	holster_reference: Instance?,
	actual_holster: Model?,
	tool: Tool?,
	mining_power: number,

	_activationConnection: RBXScriptConnection?
}, {} :: typeof(Pickaxe)))

function Pickaxe.new(PickaxeCreateInfo: Types.BaseToolCreateInfo): Pickaxe
	local self = setmetatable(BaseTool.new(PickaxeCreateInfo), Pickaxe)

	self.className = "Pickaxe"
	self.item_image = "rbxassetid://127069712406722"
	self.Designation = "Mining"

	self.holster_reference = Holster_Folder and Holster_Folder:FindFirstChild("PickaxeHolster")
	self.actual_holster = nil

	self.mining_power = 6 -- FIXED: number, not string

	self._activationConnection = nil

	return self
end

-- called when the item enters the inventory
function Pickaxe:on_give(tool: Tool, holster: Model?)
	BaseTool.on_give(self, tool, holster)

	self.tool = tool

	-- Prefer passed holster, fallback to search
	if holster then
		self.actual_holster = holster
	elseif self.holster_reference then
		self.actual_holster = utilities_module.reverse_search_holster(
			LOCAL_PLAYER,
			self.holster_reference.Name
		)
	else
		warn("[Pickaxe] Missing holster_reference")
	end

	print("Pickaxe holster set to:", self.actual_holster)

	-- Prevent connection stacking
	if self._activationConnection then
		self._activationConnection:Disconnect()
	end

	self._activationConnection = tool.Activated:Connect(function()
		self:activate()
	end)
end

-- called by your custom inventory system
function Pickaxe:equip()
	if not self.tool then return end

	local character = LOCAL_PLAYER.Character
	if not character then return end

	character.Humanoid:EquipTool(self.tool)

	if self.actual_holster then
		utilities_module.hide_holster(LOCAL_PLAYER, self.actual_holster)
	end

	print("Pickaxe equipped")
end

function Pickaxe:unequip()
	if not self.tool then return end

	local backpack = LOCAL_PLAYER:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	local character = LOCAL_PLAYER.Character
	if not character then return end

	character.Humanoid:UnequipTools()

	if self.actual_holster then
		utilities_module.show_holster(LOCAL_PLAYER, self.actual_holster)
	end

	print("Pickaxe unequipped")
end

function Pickaxe:activate()
	if not LOCAL_PLAYER.Character then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * 10

	local raycast = utilities_module.send_raycast(
		origin,
		direction,
		nil,
		{ workspace.Terrain }
	)

	if not raycast then return end

	if raycast.Instance == workspace.Terrain and raycast.Material == Enum.Material.Rock then
		print("Terrain hit at:", raycast.Position)

		-- NOTE: Server should validate this
		delete_terrain:FireServer(raycast.Position, self.mining_power)
	else
		print("No valid terrain hit")
	end
end

return Pickaxe