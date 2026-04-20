--!strict
local ConcussionStatus = {}
ConcussionStatus.__index = ConcussionStatus

local BaseStatus = require(script.Parent.Parent.BaseStatus)

setmetatable(ConcussionStatus, { __index = BaseStatus })
export type ConcussionStatus = typeof(setmetatable({} :: {
	className: "ConcussionStatus",
	name: string,
}, ConcussionStatus))

function ConcussionStatus.new(): ConcussionStatus
	local self = BaseStatus.new({
		name = "Concussion"
	})

	setmetatable(self, ConcussionStatus)

	self.className = "ConcussionStatus"

	return self
end

return ConcussionStatus