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

function BaseStatus:apply(player: Player, ...)
	player:SetAttribute(self.name, true)

	if self._apply then
		self:_apply(player, ...)
	end
	
	print("Applied")
end

function BaseStatus:un_apply(player: Player, ...)
	if not self._remove_interception then
		player:SetAttribute(self.name, nil)

		if self._un_apply then
			self:_un_apply(player, ...)
		end
	else
		self:_un_apply(player, ...)
	end
end

function BaseStatus:is_applied(player: Player) 
	if player:GetAttribute(self.name) then
		print("Is applied")
		return true
	end
	
	print("Is not applied")
	return false
end

return BaseStatus