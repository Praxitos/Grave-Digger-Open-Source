local variables_folder = game:GetService("ReplicatedStorage").Shared.Library.Configuration
--local notifications_module = require(game:GetService("ReplicatedStorage").Libraries.Shared.Notifications)

local function push_variable_func(player, key, value)
	for _, targetplayer in pairs(game.Players:GetPlayers()) do
		--notifications_module.create_variable_notification(targetplayer, player.Name,key, value)
	end
end

local function convert_value(targetType, str)
	-- If it's a string, just return
	if targetType == "string" then
		return str
	elseif targetType == "number" or targetType == "int" then
		return tonumber(str)
	elseif targetType == "boolean" then
		return str:lower() == "true"
	elseif targetType == "vector3" then
		local parts = {}
		for num in str:gmatch("[^,]+") do
			table.insert(parts, tonumber(num))
		end
		if #parts ~= 3 then
			return nil, "Vector3 requires exactly 3 numbers separated by commas"
		end
		return Vector3.new(parts[1], parts[2], parts[3])
	elseif targetType == "CFrame" then
		local parts = {}
		for num in str:gmatch("[^,]+") do
			table.insert(parts, tonumber(num))
		end
		if #parts ~= 3 then
			return nil, "Value requires exactly 3 numbers separated by commas"
		end
		return CFrame.new(parts[1], parts[2], parts[3])
	else
		return nil, "Unsupported property type: "..targetType
	end
end


return function(context, instance, var1, var2)
	if not instance then
		return "Instance '"..instance.Name .."' not found."
	end

	if not instance:FindFirst(var1) and not instance:IsA("ValueBase") then
		-- If the property is not a child value, check if it exists as a property
		if instance[var1] == nil then
			return "Property '"..var1.."' not found on instance '"..instance.Name.."'."
		end
	end

	local success, convertedValue, err

	-- Determine the target type
	local propType
	if instance:IsA("ValueBase") then
		propType = instance.ClassName:gsub("Value$", ""):lower()
		-- special case: BoolValue -> boolean
		if propType == "bool" then propType = "boolean" end
	elseif instance[var1] ~= nil then
		propType = typeof(instance[var1])
	else
		return "Cannot determine type of property '"..var1.."'"
	end

	success, convertedValue, err = pcall(function()
		return convert_value(propType, var2)
	end)

	if not success or convertedValue == nil then
		return "Failed to convert value: "..tostring(err)
	end

	-- Attempt to set the property
	local ok, setErr = pcall(function()
		if instance:IsA("ValueBase") then
			instance.Value = convertedValue
		else
			instance[var1] = convertedValue
		end
	end)

	if not ok then
		return "Failed to set "..instance.Name.."."..var1..": "..tostring(setErr)
	end

	push_variable_func(context.Executor, instance.Name, var2)
	return "Set "..instance.Name.."."..var1.." to "..tostring(convertedValue)
end
