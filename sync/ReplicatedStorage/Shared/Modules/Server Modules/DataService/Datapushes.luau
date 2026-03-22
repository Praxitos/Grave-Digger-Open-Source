local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local events_folder = ReplicatedStorage:WaitForChild("Events")
local datapush_folder = events_folder:WaitForChild("Datapush")
local datapush_remoteevent: RemoteEvent = datapush_folder:WaitForChild("Datapush")

-- lookup table
local allowedchanges_table = {
	ChatMode = true
}

function module.start_module()
	datapush_remoteevent.OnServerEvent:Connect(function(player, target, value)
		if not allowedchanges_table[target] then return end

		for _, child in ipairs(player.PlayerData:GetDescendants()) do
			if child.Name == target and child.Parent.Name ~= "Bindings" then
				child.Value = value
			end
		end
	end)
end

return module
