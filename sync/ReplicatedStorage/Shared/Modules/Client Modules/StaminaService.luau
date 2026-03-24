local module = {}

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- // Player
local LocalPlayer = Players.LocalPlayer

-- // Dynamic character refs (fixes respawn issues)
local Character = nil
local Humanoid = nil
local RootPart = nil

local function bindCharacter(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	RootPart = char:WaitForChild("HumanoidRootPart")
end

bindCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
LocalPlayer.CharacterAdded:Connect(bindCharacter)

-- // Data
local PlayerData = LocalPlayer:WaitForChild("PlayerData")
local SettingsData = PlayerData:WaitForChild("Settings Data")
local InputOptions = SettingsData:WaitForChild("Input Options")

local SprintKey = InputOptions:WaitForChild("Sprint")

local Sprint_Config = ReplicatedStorage.Shared.Library.Configuration.Character_Variables.Movement.Sprint
local BaseSpeed = Sprint_Config:WaitForChild("BaseSpeed").Value
local MaxSpeed = Sprint_Config:WaitForChild("MaxSpeed").Value
local Tick_Debounce = Sprint_Config:WaitForChild("Tick_Debounce").Value
local Tick_Speed = Sprint_Config:WaitForChild("Tick_Speed").Value
local Speed_Increase = Sprint_Config:WaitForChild("Speed_Increase").Value

local AimingUtils = require(LocalPlayer.PlayerGui:WaitForChild("Aiming"):WaitForChild("Utils"))

-- // State
local Sprinting = false
local LoopRunning = false

local KeyStates = {
	Forward = false,
	Backwards = false,
	Left = false,
	Right = false,
}

-- // Helpers
local function getKeyName(value: string): string
	return value:gsub("Enum.KeyCode.", "")
end

local function getSprintKey()
	return Enum.KeyCode[getKeyName(SprintKey.Value)]
end

local function setSprintAttribute(state: boolean)
	if Character then
		Character:SetAttribute("Sprinting", state and true or nil)
	end
end

local function resetSpeed()
	if not Character or not Humanoid then return end

	Sprinting = false          -- always clear this
	setSprintAttribute(false)  -- always clear the attribute

	if Character:GetAttribute("Aiming") then
		AimingUtils.release_breath()
	else
		Humanoid.WalkSpeed = BaseSpeed
	end
end

-- // Core loop
local function sprintLoop()
	if LoopRunning then return end
	LoopRunning = true

	setSprintAttribute(true)

	task.wait(Tick_Debounce)

	while Sprinting do
		if not Character or not Humanoid or not RootPart then break end

		-- Cancel if aiming
		if Character:GetAttribute("Aiming") then
			AimingUtils.hold_breath()
			break
		end

		-- Only accelerate forward
		if KeyStates.Forward and not KeyStates.Backwards then
			if Humanoid.WalkSpeed < MaxSpeed then
				Humanoid.WalkSpeed = math.min(
					Humanoid.WalkSpeed + Speed_Increase,
					MaxSpeed
				)
			end
		end

		-- Velocity check
		local velocity = RootPart.AssemblyLinearVelocity.Magnitude

		if math.abs(velocity - Humanoid.WalkSpeed) > 2 then
			Sprinting = false
			resetSpeed()
			break
		end

		task.wait(Tick_Speed)
	end

	LoopRunning = false
end

-- // Input
function module.start_module()
	if Humanoid then
		Humanoid.WalkSpeed = BaseSpeed
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == getSprintKey() then
			Sprinting = true
			task.spawn(sprintLoop) -- prevents yield blocking
		end

		if input.KeyCode == Enum.KeyCode.W then
			KeyStates.Forward = true
		elseif input.KeyCode == Enum.KeyCode.S then
			KeyStates.Backwards = true
		elseif input.KeyCode == Enum.KeyCode.A then
			KeyStates.Left = true
		elseif input.KeyCode == Enum.KeyCode.D then
			KeyStates.Right = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == getSprintKey() then
			Sprinting = false
			resetSpeed()
		end

		if input.KeyCode == Enum.KeyCode.W then
			KeyStates.Forward = false
		elseif input.KeyCode == Enum.KeyCode.S then
			KeyStates.Backwards = false
		elseif input.KeyCode == Enum.KeyCode.A then
			KeyStates.Left = false
		elseif input.KeyCode == Enum.KeyCode.D then
			KeyStates.Right = false
		end
	end)
end

return module