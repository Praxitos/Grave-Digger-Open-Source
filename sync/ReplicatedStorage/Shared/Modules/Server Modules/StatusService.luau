local StatusService = {}

local Status_Folder = game.ReplicatedStorage.Shared.Library.Classes.StatusClasses


local Status_Table = {}

function StatusService.give_status(player, status)
	print("Giving status:", player.Name, status)
	
	if not Status_Folder:FindFirstChild(status) then
		warn("StatusService: Status not found:", status)
		return
	end
	
	local status_module = require(Status_Folder:FindFirstChild(status))
	
	local status_instance = status_module.new()
	status_instance:apply(player)
	
	Status_Table[player.Name] = status_instance
	
	print("StatusService: Status applied:", status)
end

function StatusService.remove_status(player, status)
	print("Removing status:", player.Name, status)
	
	if not Status_Folder:FindFirstChild(status) then
		warn("StatusService: Status not found:", status)
		return
	end
	
	local status_module = require(Status_Folder:FindFirstChild(status))
	
	local status_instance = Status_Table[player.Name]
	status_instance:un_apply(player)
	
	Status_Table[player.Name] = nil
	
	print("StatusService: Status removed:", status)
end




return StatusService
