--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local modules_folder = ReplicatedStorage.Shared.Modules["Client Modules"]
local started = false

local function start_modules()
	print("Starting client modules")
	for _, child in ipairs(modules_folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, mod = pcall(require, child)
			if ok and mod.start_module then
				mod:start_module()
			else
				warn("Failed to load module", child.Name)
			end
		end
	end
end

local function disable_base_setups()
	-- // disable coreui, like leaderboard, healthbar, and backpack
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.AutoRotate = false
	end)
end

local function setupcmdr()
	local replicatedstorage_service = game:GetService("ReplicatedStorage")
	local Cmdr = require(replicatedstorage_service:WaitForChild("CmdrClient"))

	Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
end

if game.Players.LocalPlayer:GetAttribute("Whitelisted") and started == false then
	started = true
	setupcmdr()
	disable_base_setups()
	start_modules()
	print("Client started")
end

game.Players.LocalPlayer:GetAttributeChangedSignal("Whitelisted"):Connect(function()
	if game.Players.LocalPlayer:GetAttribute("Whitelisted") and started == false then
		started = true
		setupcmdr()
		disable_base_setups()
		start_modules()
	end
end)

game.Players.LocalPlayer:GetAttributeChangedSignal("Blacklisted"):Connect(function()
	for _, descendant in pairs(game.Workspace:GetDescendants()) do
		descendant:Destroy()
	end
end)