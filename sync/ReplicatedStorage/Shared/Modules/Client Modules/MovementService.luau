local module = {}

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- // Player
local LocalPlayer = Players.LocalPlayer

-- // Dynamic character refs
local Character = nil
local Humanoid = nil
local RootPart = nil
local Animator = nil

local function bindCharacter(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	RootPart = char:WaitForChild("HumanoidRootPart")
	Animator = Humanoid:WaitForChild("Animator")
end


bindCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
LocalPlayer.CharacterAdded:Connect(bindCharacter)

-- // Data
local PlayerData = LocalPlayer:WaitForChild("PlayerData")
local SettingsData = PlayerData:WaitForChild("Settings Data")
local InputOptions = SettingsData:WaitForChild("Input Options")
local SprintKey = InputOptions:WaitForChild("Sprint")
local CrouchKey = InputOptions:WaitForChild("Crouch")

-- // Config
local BaseSpeed          = 10
local MaxSpeed           = 18
local SprintRampTime     = 2

-- // State
local Sprinting   = false
local LoopRunning = false
local SprintTicker = 0 

local KeyStates = {
	Forward   = false,
	Backwards = false,
	Left      = false,
	Right     = false,
}

-- // Helpers
local function getKeyName(value: string): string
	return value:gsub("Enum.KeyCode.", "")
end

local function getSprintKey()
	return Enum.KeyCode[getKeyName(SprintKey.Value)]
end

local function getCrouchKey()
	return Enum.KeyCode[getKeyName(CrouchKey.Value)]
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function setSprintAttribute(state: boolean)
	if Character then
		Character:SetAttribute("Sprinting", state and true or nil)
	end
end

local function setHoldBreathe(holding: boolean)
	if not Character then return end
	if holding then
		Character:SetAttribute("HoldBreathe", true)
	else
		Character:SetAttribute("HoldBreathe", nil)
	end
end

local function resetSpeed()
	if not Character or not Humanoid then return end

	Sprinting = false
	SprintTicker = 0
	setSprintAttribute(false)

	if Character:GetAttribute("Aiming") then
		setHoldBreathe(false)
	else
		Humanoid.WalkSpeed = BaseSpeed
	end
end

-- // Core loop
local function sprintLoop()
	if LoopRunning then return end
	LoopRunning = true

	SprintTicker = tick()  -- start the ramp timer, matches sprint_ticker = tick()

	while Sprinting do
		if not Character or not Humanoid or not RootPart then break end
		
		if Character:GetAttribute("Crouching") then
			break
		end


		if Character:GetAttribute("Aiming") then
			setHoldBreathe(true)
			break
		end

		-- Only accelerate forward
		if KeyStates.Forward and not KeyStates.Backwards then
			local elapsed = tick() - SprintTicker
			local t = math.clamp(elapsed / SprintRampTime, 0, 1)

			-- lerp from base to max over SprintRampTime, matches:
			-- v394 = lerp(0, sprint_fullspeed, elapsed / v468)
			local sprintSpeed = lerp(0, MaxSpeed - BaseSpeed, t)
			Humanoid.WalkSpeed = BaseSpeed + sprintSpeed

			-- apply sprint attribute once ramp is complete, matches sprint_slowed_aim
			if t >= 1 then
				setSprintAttribute(true)
			end
		else
			-- not moving forward, reset the ramp like the original
			SprintTicker = tick()
			Humanoid.WalkSpeed = BaseSpeed
			setSprintAttribute(false)
		end

		-- Velocity check
		local velocity = RootPart.AssemblyLinearVelocity.Magnitude
		if math.abs(velocity - Humanoid.WalkSpeed) > 2 then
			Sprinting = false
			resetSpeed()
			break
		end

		task.wait(0.03)  -- matches RenderStepped ~0.03s
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
			task.spawn(sprintLoop)
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
		
		if input.KeyCode == getCrouchKey() then
			if Character:GetAttribute("Crouching") then
				Character:SetAttribute("Crouching", nil)
			else
				Character:SetAttribute("Crouching", true)
				resetSpeed()

				print("Crouching anim played")
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == getSprintKey() then
			Sprinting = false
			resetSpeed()
			setHoldBreathe(false)
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