local module = {}

local datastore_service = game:GetService("DataStoreService")

module.datastores_table = {
	["restores"] = datastore_service:GetDataStore("restores"),
}

local function push_data(store, data)
	local success, err = pcall(function()
		store:SetAsync(data.key, data.value)
	end)

	if not success then
		return "WARN:: push_data function call failure! " .. (err or "No log.")
	else
		return "push_data success!"
	end
end

function module.data_push(store_name: string, data: SharedTable, key: string, replace: boolean)
	local datastore = module.datastores_table[store_name]
	if not datastore then return end
	if typeof(data) ~= "table" then return end
	if typeof(key) ~= "string" then return end
	replace = replace ~= false

	if replace then
		return push_data(datastore, {key = key, value = data})
	else
		local success, old_table = pcall(function()
			return datastore:GetAsync(key) or {}
		end)

		if not success then
			return "WARN:: failed to retrieve old data: " .. tostring(old_table)
		end

		for k, v in pairs(data) do
			old_table[k] = v
		end

		return push_data(datastore, {key = key, value = old_table})
	end
end


function module.data_retrieve(store_name, key)
	local datastore = module.datastores_table[store_name]
	if not datastore then return "data_retrieve could not find store_name" end
	-- // check to see if theres a key within said datastore of that specific thing
	return datastore:GetAsync(key) or "data_retrieve could not find key, or it is empty."
end

return module
