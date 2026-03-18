--!strict

local Util = {}

-- Deep copy table
function Util.deepCopy(src: {}): {}
	local copy = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			copy[k] = Util.deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- Merge tables recursively
function Util.merge(dest: {}, src: {}): {}
	for k, v in pairs(src) do
		if type(v) == "table" and type(dest[k]) == "table" then
			Util.merge(dest[k], v)
		else
			dest[k] = v
		end
	end
	return dest
end

function Util.quick_weld(p0, p1, parent, name, weld_type)
	if not weld_type then weld_type = Instance.new("Weld") end

	weld_type.Part0 = p0
	weld_type.Part1 = p1
	weld_type.Parent = parent
	weld_type.Name = name
end

function Util.hide_holster(player: Player, holster_reference: Instance)
	for _, child in pairs(holster_reference:GetDescendants()) do
		if child:GetAttribute("Hide_On_Equip") then
			child.Transparency = 1
		end
	end	
end

function Util.show_holster(player: Player, holster_reference: Instance)
	for _, child in pairs(holster_reference:GetDescendants()) do
		if child:GetAttribute("Hide_On_Equip") then
			child.Transparency = 0
		end
	end	
end

-- // only use when you know the holster is there
function Util.reverse_search_holster(player: Player, name: string)
	print("Player, name is:", player.Name, name)

	local character = player.Character or player.CharacterAdded:Wait()
	local characterData = character:WaitForChild("CharacterData")
	local renderedHolsters = characterData:WaitForChild("Rendered_Holsters")

	local holster = renderedHolsters:WaitForChild(name)
	

	if not holster then
		warn("Could not find holster with:", name)
	end

	return holster
end

function Util.send_raycast(origin: Vector3, direction: Vector3, blacklist: table, whitelist: table)
	if not origin or not direction then warn("[SEND_RAYCAST() FAILED! Origin/Direction not provided") return end

    local raycast_params = RaycastParams.new()

	if blacklist then
		raycast_params.FilterType = Enum.RaycastFilterType.Blacklist
    	raycast_params.FilterDescendantsInstances = blacklist
	elseif whitelist then
		raycast_params.FilterType = Enum.RaycastFilterType.Whitelist
		raycast_params.FilterDescendantsInstances = whitelist
	end
	
    local raycast_result = workspace:Raycast(origin, direction, raycast_params)
    return raycast_result
end

function Util.MakeFuzzyFinder(list)
	local function score(str, pat)
		local score = 0
		local ip = 1
		for i = 1, #pat do
			local j = string.find(str, string.sub(pat, i, i), j or 1, true)
			if j then
				score += 1 / (0.1 + j + i / #pat)
				ip = i + 1
			end
		end
		return score
	end

	return function(text)
		table.sort(list, function(a, b)
			return score(a, text) > score(b, text)
		end)
		return list
	end
end

function Util.GetNames(list)
	local names = {}
	for _, item in list do
		table.insert(names, typeof(item) == "Instance" and item.Name or tostring(item))
	end
	return names
end

return Util

