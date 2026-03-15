local function setupcmdr()
	local replicatedstorage_service = game:GetService("ReplicatedStorage")
	local Cmdr = require(replicatedstorage_service:WaitForChild("CmdrClient"))

	Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
end

setupcmdr()