return function(context, store, key)
	local datastores = require(game.ServerScriptService.DataService.Datastores)
	local store_table = datastores.data_retrieve(store, key)

	if typeof(store_table) == "table" then
		if next(store_table) == nil then
			return "datastoreServer: no entries."
		else
			return table.concat(store_table, "\n")
		end
	else
		return store_table
	end
end
