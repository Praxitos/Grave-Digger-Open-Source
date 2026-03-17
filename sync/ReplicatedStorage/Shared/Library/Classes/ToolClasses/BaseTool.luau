-- This file is a part of the ... library. ... is licensed under the terms of the MIT License. For more information, see LICENSE.md

--!strict
--!native
--!optimize 2

-- Library Dependencies
local Types = require(script.Parent.Parent.Parent.Types);

-- Class Definition
--[=[
	@class BaseTool

	The BaseTool class is Base Tool Class
]=]
local BaseTool = {};
BaseTool.__index = BaseTool;

-- Type Definition
export type BaseTool = typeof(setmetatable({} :: {
	className : "BaseTool";
}, {} :: typeof(BaseTool)))

--[=[
	@within BaseTool

	The BaseTool class is Base Tool Class

	@param BaseToolCreateInfo heraTypes.BaseToolCreateInfo
	@return BaseTool
]=]
function BaseTool.new(BaseToolCreateInfo : Types.BaseToolCreateInfo) : BaseTool
	local class = setmetatable({}, BaseTool);
	class.className = "BaseTool";
	class.name = BaseToolCreateInfo.name;

	return class;
end

--[=[
	@within BaseTool

]=]

function BaseTool:on_give()
end

function BaseTool:on_equip()
end

function BaseTool:on_activation()
end

function baseTool:on_unequip()
end

return BaseTool;