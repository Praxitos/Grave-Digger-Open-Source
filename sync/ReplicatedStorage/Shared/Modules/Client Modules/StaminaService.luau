local module = {}

-- // Variables
local player_service = game:GetService("Players")
local replicatedstorage_service = game:GetService("ReplicatedStorage")
local input_service = game:GetService("UserInputService")

local LocalPlayer = player_service.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

local PlayerData = LocalPlayer:WaitForChild("PlayerData")
local SettingsData = PlayerData:WaitForChild("Settings Data")
local InputOptions = SettingsData:WaitForChild("Input Options")

local SprintKey = InputOptions:WaitForChild("Sprint")

local Stamina_Config = replicatedstorage_service.Shared.Library.Configuration.Character_Variables.Movement.Sprint
local BaseSpeed = Stamina_Config:WaitForChild("BaseSpeed").Value
local MaxSpeed = Stamina_Config:WaitForChild("MaxSpeed").Value
local Tick_Debounce = Stamina_Config:WaitForChild("Tick_Debounce").Value
local Tick_Speed = Stamina_Config:WaitForChild("Tick_Speed").Value
local Speed_Increase = Stamina_Config:WaitForChild("Speed_Increase").Value

-- // State
local Sprinting = false
local Increasing = false

local Key_States = {
	["Forward"] = false,
	["Backwards"] = false,
	["Left"] = false,
	["Right"] = false,
}

-- // Functions
local function getKeyName(value: string): string
	return value:gsub("Enum.KeyCode.", "")
end

local function getSprintKey()
	return Enum.KeyCode[getKeyName(SprintKey.Value)]
end

local function resetSpeed()
	Humanoid.WalkSpeed = BaseSpeed
end

local function sprintLoop()
	if Increasing then return end
	Increasing = true

	task.wait(Tick_Debounce)

	while Sprinting do
		if Humanoid.WalkSpeed < MaxSpeed and Key_States["Forward"] == true and Key_States["Backwards"] == false then
			Humanoid.WalkSpeed = math.min(
				Humanoid.WalkSpeed + Speed_Increase,
				MaxSpeed
			)

			-- // print current velocity
			local velocity = Character.HumanoidRootPart.AssemblyLinearVelocity
			local true_speed = velocity.Magnitude

			print("Current Velocity:", velocity, "Current Speed:", true_speed)

			-- if the true speed is not within two number range of current speed, quit sprint and reset
		end
		
		local velocity = Character.HumanoidRootPart.AssemblyLinearVelocity
		local true_speed = velocity.Magnitude

		if math.abs(true_speed - Humanoid.WalkSpeed) > 2 then
			Sprinting = false
			resetSpeed()
			print("Speed desync detected. Resetting speed.")
			break
		end

		task.wait(Tick_Speed)
	end

	Increasing = false
end

-- // Connections
function module.start_module()

	Humanoid.WalkSpeed = BaseSpeed

	input_service.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == getSprintKey() then
			Sprinting = true
			sprintLoop()
		end

		if input.KeyCode == Enum.KeyCode.W then
			Key_States["Forward"] = true
		elseif input.KeyCode == Enum.KeyCode.S then
			Key_States["Backwards"] = true
		elseif input.KeyCode == Enum.KeyCode.A then
			Key_States["Left"] = true
		elseif input.KeyCode == Enum.KeyCode.D then
			Key_States["Right"] = true
		end
	end)

	input_service.InputEnded:Connect(function(input)
		if input.KeyCode == getSprintKey() then
			Sprinting = false
			resetSpeed()
		end

		if input.KeyCode == Enum.KeyCode.W then
			Key_States["Forward"] = false
		elseif input.KeyCode == Enum.KeyCode.S then
			Key_States["Backwards"] = false
		elseif input.KeyCode == Enum.KeyCode.A then
			Key_States["Left"] = false
		elseif input.KeyCode == Enum.KeyCode.D then
			Key_States["Right"] = false
		end
	end)

end

return module