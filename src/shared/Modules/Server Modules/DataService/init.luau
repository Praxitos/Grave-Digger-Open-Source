local module = {}

-- // services
local replicated_storage = game:GetService("ReplicatedStorage")
local players_service = game:GetService("Players")

-- // dependencies
local externals_folder = replicated_storage.Shared.Library.Externals
local profileservice_module = require(externals_folder.ProfileService)

local template_module = require(script.Template)
local utilities_module = require(script.Utilities)

local datastore_module = require(script.Datastores)


-- // profile store
local playerstore_key = profileservice_module.GetProfileStore(
	"PlayerData",
	template_module
)

-- // runtime state
local active_profiles = {}

-- // functions
local function update_table_data(player: Player)
	local profile = active_profiles[player]
	if not profile then return end
	local data_root = profile.Data
	local config_root = player:FindFirstChild("PlayerData")
	if not config_root then return end

	-- Cache to store instance paths
	local instance_paths = {}
	------------------------------------------------
	-- Resolve Instance → parent table + key
	------------------------------------------------
	local function resolve_parent_and_key(instance: Instance)
		local names = {}
		local current = instance
		while current and current ~= config_root do
			table.insert(names, 1, current.Name)
			current = current.Parent
		end
		local parent = data_root
		for i = 1, #names - 1 do
			parent[names[i]] = parent[names[i]] or {}
			parent = parent[names[i]]
		end
		return parent, names[#names]
	end
	------------------------------------------------
	-- Resolve using cached path
	------------------------------------------------
	local function resolve_with_cache(instance: Instance)
		local cached = instance_paths[instance]
		if cached then
			local parent = data_root
			for i = 1, #cached - 1 do
				if not parent[cached[i]] then
					return nil, nil
				end
				parent = parent[cached[i]]
			end
			return parent, cached[#cached]
		end
		return resolve_parent_and_key(instance)
	end
	------------------------------------------------
	-- Write instance into table
	------------------------------------------------
	local function write_instance(instance: Instance)
		local parent_table, key = resolve_parent_and_key(instance)
		if not parent_table or not key then 
			return 
		end

		-- Cache the path
		local names = {}
		local current = instance
		while current and current ~= config_root do
			table.insert(names, 1, current.Name)
			current = current.Parent
		end
		instance_paths[instance] = names

		if instance:IsA("ValueBase") then
			parent_table[key] = instance.Value
		else
			parent_table[key] = parent_table[key] or {}
		end
	end
	------------------------------------------------
	-- Remove instance from table
	------------------------------------------------
	local function remove_instance(instance: Instance)
		local parent_table, key = resolve_with_cache(instance)
		if parent_table and key then
			parent_table[key] = nil
			-- Clean up cache
			instance_paths[instance] = nil
		end
	end
	------------------------------------------------
	-- Track one instance
	------------------------------------------------
	local function track_instance(instance: Instance)
		local old_name = instance.Name

		write_instance(instance)

		-- Property changes
		instance.Changed:Connect(function(property)
			-- Rename
			if property == "Name" then
				local parent_table, _ = resolve_parent_and_key(instance)
				if parent_table then
					parent_table[instance.Name] = parent_table[old_name]
					parent_table[old_name] = nil
					old_name = instance.Name
					-- Update cache
					write_instance(instance)
				end
			end
			-- Value update
			if property == "Value" and instance:IsA("ValueBase") then
				local parent_table, key = resolve_parent_and_key(instance)
				if parent_table and key then
					parent_table[key] = instance.Value
				end
			end
		end)
		-- Reparenting/Removal detection
		instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(config_root) then
				-- Instance was removed from PlayerData, remove from table
				remove_instance(instance)
			else
				-- Instance was reparented within PlayerData, update location
				write_instance(instance)
			end
		end)
		-- Track children being added/removed
		instance.ChildAdded:Connect(function(child)
			track_instance(child)
		end)
		instance.ChildRemoved:Connect(function(child)
			remove_instance(child)
		end)
		-- Initial children
		for _, child in ipairs(instance:GetChildren()) do
			track_instance(child)
		end
	end
	------------------------------------------------
	-- Start tracking
	------------------------------------------------
	track_instance(config_root)
end

local function retrieve_restores()
	local restore_table = datastore_module.data_retrieve("restores", "main")
	return restore_table
end

local function load_profile(player: Player)
	local profile_key = "Player_" .. player.UserId

	local profile = playerstore_key:LoadProfileAsync(profile_key)

	if not profile then
		player:Kick("Failed to load data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile:ListenToRelease(function()
		active_profiles[player] = nil

		if player and player.Parent then
			player:Kick("Data loaded on another server.")
		end
	end)

	-- Safety check: player left during load
	if not player:IsDescendantOf(players_service) then
		profile:Release()
		return
	end

	active_profiles[player] = profile

	utilities_module.visualize_table(player, profile.Data)
	update_table_data(player)
	
	local restores = retrieve_restores()
	if typeof(restores) == "table" then
		local index = table.find(restores, player.UserId)
		if index then
			player:WaitForChild("PlayerData"):WaitForChild("CharacterData"):WaitForChild("Wiped").Value = false
			table.remove(restores, index)
			datastore_module.data_push("restores", restores, "main", true)
			print("restoreServer: restored player data for", player.Name)
		end
	end
end

local function release_profile(player: Player)
	local profile = active_profiles[player]

	if profile then
		profile:Release()
		active_profiles[player] = nil
	end
end

-- // api

function module.start_module()
	-- Existing players
	for _, player in pairs(players_service:GetPlayers()) do
		task.spawn(load_profile, player)
	end

	-- Player join
	players_service.PlayerAdded:Connect(function(player)
		task.spawn(load_profile, player)
	end)

	-- Player leave
	players_service.PlayerRemoving:Connect(function(player)
		release_profile(player)
	end)
	
	
end

function module.wipe_player_data(player: Player, wipe_type)
	print("wipeServer: wiping data for", player.Name, "type:", wipe_type)
	local profile = active_profiles[player]
	if not profile then warn("No active profile found for player: " .. player.Name) return end

	local function deep_copy(t)
		local copy = {}
		for k, v in pairs(t) do
			if type(v) == "table" then
				copy[k] = deep_copy(v)
			else
				copy[k] = v
			end
		end
		return copy
	end

	-- Wipe data in memory
	if wipe_type == 0 then
		-- Wipe only CharacterData
		if profile.Data.CharacterData then
			for key, _ in pairs(profile.Data.CharacterData) do
				profile.Data.CharacterData[key] = nil
			end

			local template_character_data = template_module.CharacterData
			for key, value in pairs(template_character_data) do
				if type(value) == "table" then
					profile.Data.CharacterData[key] = deep_copy(value)
				else
					profile.Data.CharacterData[key] = value
				end
			end
		end
	else
		-- Wipe all player data
		for key, _ in pairs(profile.Data) do
			profile.Data[key] = nil
		end
		for key, value in pairs(template_module) do
			if type(value) == "table" then
				profile.Data[key] = deep_copy(value)
			else
				profile.Data[key] = value
			end
		end
	end

	-- Use a flag to prevent kick during internal release
	local releasing_for_wipe = module._internal_releasing or {}
	releasing_for_wipe[player] = true
	module._internal_releasing = releasing_for_wipe

	-- Safely release profile
	profile:Release()
	active_profiles[player] = nil

	-- Destroy old PlayerData instance
	local playerdata = player:FindFirstChild("PlayerData")
	if playerdata then
		playerdata:Destroy()
	end

	-- Give ProfileService a small moment to finalize release before reloading
	task.wait(0.1)

	-- Reload the profile
	task.spawn(function()
		load_profile(player)
	end)
end



return module
