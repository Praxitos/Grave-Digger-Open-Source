local replicatedfirst = script.Parent


replicatedfirst:RemoveDefaultLoadingScreen()

local intro_frame = game.Players.LocalPlayer.PlayerGui:WaitForChild("Intro")
local userinputservice = game:GetService("UserInputService")
local tween_service = game:GetService("TweenService")

intro_frame.Enabled = true


local function set_invsible()
	for _, v in pairs(intro_frame:GetDescendants()) do
		if v:IsA("TextLabel") then
			local tween = tween_service:Create(v, TweenInfo.new(0.5), {TextTransparency = 1})
			tween:Play()
		elseif v:IsA("ImageLabel") then
			local tween = tween_service:Create(v, TweenInfo.new(0.5), {ImageTransparency = 1})
			tween:Play()
		elseif v:IsA("Frame") then
			local tween = tween_service:Create(v, TweenInfo.new(0.5), {BackgroundTransparency = 1})
			tween:Play()
		end
	end
	-- REMOVE LATER
	local MusicPlayer = workspace.MusicPlayer.music
	local tween = tween_service:Create(MusicPlayer, TweenInfo.new(3), {Volume = 0.35})
	tween:Play()
end

userinputservice.InputBegan:Connect(function(input, gps)
	if gps then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		set_invsible()
	end
end)


task.delay(20, function()
	set_invsible()
end)