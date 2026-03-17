--!strict
--!native
--!optimize 2

local Types = require(script.Parent.Parent.Parent.Types)

local BaseGun = {}
BaseGun.__index = BaseGun

export type BaseGun = typeof(setmetatable({} :: {
	className: "BaseGun",
	name: string,
}, {} :: typeof(BaseGun)))

function BaseGun.new(BaseGunCreateInfo: Types.BaseGunCreateInfo): BaseGun
	local class = setmetatable({}, BaseGun)

	class.className = "BaseGun"
	class.name = BaseGunCreateInfo.name

	return class
end

function BaseGun:Foo()
end

return BaseGun