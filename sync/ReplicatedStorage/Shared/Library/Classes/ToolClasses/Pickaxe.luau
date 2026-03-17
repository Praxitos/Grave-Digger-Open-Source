local Types = require(script.Parent.Parent.Parent.Types)

local BaseTool = require(script.Parent.BaseTool)

local Pickaxe = {}
Pickaxe.__index = Pickaxe
setmetatable(Pickaxe, BaseTool) -- inherit methods

export type Pickaxe = typeof(setmetatable({} :: {
	className : "Pickaxe";
}, {} :: typeof(Pickaxe)))

function Pickaxe.new(PickaxeCreateInfo : Types.BaseToolCreateInfo) : Pickaxe
	local class = setmetatable({}, Pickaxe)

	class.className = "Pickaxe"
	class.name = PickaxeCreateInfo.name
	class.holster_reference = Instance.new("Part")

	return class
end

function Pickaxe:on_give()
	print("Gave Pickaxe")
end

return Pickaxe