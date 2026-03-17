-- This file is a part of the ... library. ... is licensed under the terms of the MIT License. For more information, see LICENSE.md

--!strict
--!native
--!optimize 2

-- Library Dependencies
local Types = require(script.Parent.Parent.Parent.Types);

-- Class Definition
--[=[
	@class BaseGun

	The BaseGun class is the primary GunClass
]=]
local BaseGun = {};
BaseGun.__index = BaseGun;

-- Type Definition
export type BaseGun = typeof(setmetatable({} :: {
	className : "BaseGun";
}, {} :: typeof(BaseGun)))

--[=[
	@within BaseGun

	The BaseGun class is the primary GunClass

	@param BaseGunCreateInfo heraTypes.BaseGunCreateInfo
	@return BaseGun
]=]
function BaseGun.new(BaseGunCreateInfo : Types.BaseGunCreateInfo) : BaseGun
	local class = setmetatable({}, BaseGun);
	class.className = "BaseGun";
	class.name = BaseGunCreateInfo.name;

	return class;
end

--[=[
	@within BaseGun

]=]
function BaseGun:Foo()

end

return BaseGun;