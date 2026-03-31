--!strict
local BaseStatus = {}
BaseStatus.__index = BaseStatus

export type BaseStatus = typeof(setmetatable({} :: {
	className: "BaseStatus",
	name: string,
}, BaseStatus))

function BaseStatus.new(info: { name: string }): BaseStatus
	local self = setmetatable({}, BaseStatus)

	self.className = "BaseStatus"
	self.name = info.name

	return self
end

function BaseStatus:apply(player: Player)
	player:SetAttribute(self.name, true)

	if self._apply then
		self:_apply(player)
	end
end

function BaseStatus:un_apply(player: Player)
	player:SetAttribute(self.name, false)

	if self._un_apply then
		self:_un_apply(player)
	end
end

return BaseStatus