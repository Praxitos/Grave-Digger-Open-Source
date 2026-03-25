local module = {}

local notifications_screengui = script.Parent
local main_frame = notifications_screengui.Main
local example = main_frame.Example

local tween_service = game:GetService("TweenService")
local run_service = game:GetService("RunService")

-- // rich text is enabled
function module.send_notification(players, text)
	
	-- // if its the client, then we automatically assume we want to notify purely the local player
	if run_service:IsClient() then
		local example_clone = example:Clone()
		example_clone.Parent = main_frame
		example_clone.Visible = true
		example_clone.Text = text
		example_clone.TextTransparency = 0
		
		task.delay(3, function()
			local tween = tween_service:Create(example_clone, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {TextTransparency = 1})
			tween:Play()
			tween.Completed:Wait()
			example_clone:Destroy()
		end)
	else
		-- // TODO: add server input
		
	end
	
end

return module
