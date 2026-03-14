return function(context, player, addPlayer)
	local datastoreservice = require(game.ServerScriptService.DataService.Datastores)
	addPlayer = addPlayer ~= false -- default true

	local userId = game.Players:GetUserIdFromNameAsync(player)
	local data_table = datastoreservice.data_retrieve("restores", "main")

	if addPlayer then
		if typeof(data_table) ~= "table" then
			data_table = {userId}
			datastoreservice.data_push("restores", data_table, "main", false)
		else
			-- Only insert if userId isn't already in the table
			if not table.find(data_table, userId) then
				table.insert(data_table, userId)
				datastoreservice.data_push("restores", data_table, "main", true)
			end
		end
	else
		if typeof(data_table) ~= "table" then
			return "restoreServer: data_table has no entries"
		end

		local index = table.find(data_table, userId)
		if not index then
			return "restoreServer: player is not in the restore list"
		end

		table.remove(data_table, index)
		datastoreservice.data_push("restores", data_table, "main", true)
	end
end
