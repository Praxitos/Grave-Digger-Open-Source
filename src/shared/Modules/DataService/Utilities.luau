local module = {}

local function deep_recursive_create(parent, data_table)
	for key_name, value_inset in pairs(data_table) do
		local instance_name = typeof(key_name) == "string" and key_name or tostring(key_name)

		if typeof(value_inset) == "table" then
			local folder = Instance.new("Folder")
			folder.Name = instance_name
			folder.Parent = parent

			deep_recursive_create(folder, value_inset)

		elseif typeof(value_inset) == "string" then
			local value = Instance.new("StringValue")
			value.Name = instance_name
			value.Value = value_inset
			value.Parent = parent

		elseif typeof(value_inset) == "number" then
			local value = Instance.new("NumberValue")
			value.Name = instance_name
			value.Value = value_inset
			value.Parent = parent

		elseif typeof(value_inset) == "boolean" then
			local value = Instance.new("BoolValue")
			value.Name = instance_name
			value.Value = value_inset
			value.Parent = parent
		end
	end
end

function module.visualize_table(player: Player, data)

	if typeof(data) ~= "table" then return end

	if player:FindFirstChild("PlayerData") then
		return
	end

	local configuration = Instance.new("Configuration")
	configuration.Name = "PlayerData"
	configuration.Parent = player

	deep_recursive_create(configuration, data)
end

return module
