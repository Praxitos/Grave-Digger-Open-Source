--!strict

local module = {}

--////////////////////////////////////////////////////////
-- References
--////////////////////////////////////////////////////////

local Aiming_Screengui = script.Parent
local hold_breath_image_label = Aiming_Screengui:WaitForChild("hold_breath")

local TweenService = game:GetService("TweenService")
local main_util = require(game:GetService("ReplicatedStorage").Shared.Library.Util)

--////////////////////////////////////////////////////////
-- State
--////////////////////////////////////////////////////////

local old_fov: number? = nil
local holding: boolean = false

--////////////////////////////////////////////////////////
-- Hold Breath
--////////////////////////////////////////////////////////

function module.hold_breath()
	if holding then return end
	holding = true

	local camera = workspace.CurrentCamera
	if not camera then return end

	old_fov = camera.FieldOfView

	-- UI fade in
	local image_tween = TweenService:Create(
		hold_breath_image_label,
		TweenInfo.new(1),
		{ ImageTransparency = 0 }
	)

	-- Zoom in
	local fov_tween = TweenService:Create(
		camera,
		TweenInfo.new(1),
		{ FieldOfView = 60 }
	)

	image_tween:Play()
	fov_tween:Play()
end

--////////////////////////////////////////////////////////
-- Release Breath
--////////////////////////////////////////////////////////

function module.release_breath()
	if not holding then return end
	holding = false

	local camera = workspace.CurrentCamera
	if not camera then return end

	-- UI fade out
	local image_tween = TweenService:Create(
		hold_breath_image_label,
		TweenInfo.new(0.5),
		{ ImageTransparency = 1 }
	)

	-- Restore FOV
	local fov_tween = TweenService:Create(
		camera,
		TweenInfo.new(0.5),
		{ FieldOfView = old_fov or 70 }
	)

	image_tween:Play()
	fov_tween:Play()

	main_util.applyRecoil(100, 10, 25)
end

return module