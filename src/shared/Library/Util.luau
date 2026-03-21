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

function Util.register_animations(player: Player, animations_table: table)
	print("UTIL:: Received registering animations with:", player.Name, animations_table)
	local character = player.Character
	if not character then
		warn("register_animations: Character not found for", player.Name)
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("register_animations: Humanoid not found for", player.Name)
		return nil
	end

	local animator: Animator = humanoid:FindFirstChildOfClass("Animator")
	
	if not animator then
		warn("register_animations: Animator not found, creating one for", player.Name)
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local Animations = {}

	for name, anim in pairs(animations_table) do
		print("Checking", anim.Name, "has value of:", anim.AnimationId)
		
		--  Type safety check
		if typeof(anim) ~= "Instance" or not anim:IsA("Animation") then
			warn("Invalid animation for key:", name, "| Expected Animation, got:", typeof(anim))
			continue
		end

		-- Asset ID check
		if not anim.AnimationId or anim.AnimationId == "" then
			warn("Animation missing AnimationId:", name)
			continue
		end

		--  Safe load
		local success, loadedAnim = pcall(function()
			return animator:LoadAnimation(anim)
		end)

		if success and loadedAnim then
			Animations[name] = loadedAnim
		else
			warn("Failed to load animation:", name, loadedAnim)
		end
	end

	return Animations
end

function Util.emit_part(part: Part)
	for _, child in pairs(part:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			child:Emit(child:GetAttribute("EmitCount") or 1)
		end
	end
end

return Util

