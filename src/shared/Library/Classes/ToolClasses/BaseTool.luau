local BaseTool = {}
BaseTool.__index = BaseTool

export type BaseTool = typeof(setmetatable({} :: {
	className: "BaseTool",
	name: string,
	tool: Tool?
}, {} :: typeof(BaseTool)))

function BaseTool.new(BaseToolCreateInfo: Types.BaseToolCreateInfo): BaseTool
	local self = setmetatable({}, BaseTool)

	self.className = "BaseTool"
	self.name = BaseToolCreateInfo.name
	self.tool = nil

	return self
end

function BaseTool:on_give(tool: Tool, holster: Model?)
	self.tool = tool
end

function BaseTool:equip()
	error(self.className .. " missing equip()")
end

function BaseTool:unequip()
	error(self.className .. " missing unequip()")
end

function BaseTool:activate()
	error(self.className .. " missing activate()")
end

return BaseTool