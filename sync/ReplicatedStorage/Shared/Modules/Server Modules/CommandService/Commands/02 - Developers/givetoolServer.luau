local item_service = require(game:GetService("ReplicatedStorage").Shared.Modules["Server Modules"].ItemsService)

return function(_, players, toolClasses)
	print("Received with:", players, toolClasses)
	for _, player in pairs(players) do
		for _, tool in pairs(toolClasses) do
			item_service.give_item(player, tool)
		end
	end

	return "Gave tool(s)"
end