local StatusService = {}

local Status_Folder = game.ReplicatedStorage.Shared.Library.Classes.StatusClasses

-- [player] = { [statusName] = status_instance }
local Status_Table = {}

function StatusService.give_status(player, status, ...)
	local args = {...}
	print("Giving status:", player.Name, status, args)

	local status_module_script = Status_Folder:FindFirstChild(status)
	if not status_module_script then
		warn("StatusService: Status not found:", status)
		return
	end

	local status_module = require(status_module_script)

	local status_instance = status_module.new()
	status_instance:apply(player, ...)

	-- Initialize player table if needed
	Status_Table[player] = Status_Table[player] or {}

	-- Store by status name
	Status_Table[player][status] = status_instance

	print("StatusService: Status applied:", status)
end

function StatusService.remove_status(player, status)
	print("Removing status:", player.Name, status)

	local status_module_script = Status_Folder:FindFirstChild(status)
	if not status_module_script then
		warn("StatusService: Status not found:", status)
		return
	end

	local player_statuses = Status_Table[player]
	if not player_statuses then
		warn("No statuses found for player:", player.Name)
		return
	end

	local status_instance = player_statuses[status]
	if not status_instance then
		warn("Status not applied to player:", status)
		return
	end

	status_instance:un_apply(player)

	-- Only remove if fully unapplied
	if not status_instance:is_applied(player) then
		player_statuses[status] = nil

		-- Cleanup empty table
		if next(player_statuses) == nil then
			Status_Table[player] = nil
		end

		print("StatusService: Status removed:", status)
	end
end


function StatusService.remove_all_statuses(player)
	print("Removing all statuses for player:", player.Name)
	
	for _, status in pairs(Status_Table[player] or {}) do
		if status:is_applied(player) then
			status:un_apply(player)
		end
	end
end

return StatusService