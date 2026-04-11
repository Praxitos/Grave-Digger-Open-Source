local run_service = game:GetService("RunService")

local debug_screenui = script.Parent
local main_frame = debug_screenui.Main
local fps_frames = main_frame.FPS

local currentframes_textlabel = fps_frames.CurrentFrames
local averageframes_textlabel = fps_frames.AverageFPS

-- // current FPS smoothing
local displayed_fps = 60
local smoothing = 0.15

-- // rolling average (last 10 frames)
local frame_deltas = {}
local max_samples = 50
local total_time = 0

run_service.RenderStepped:Connect(function(delta_time)
	if delta_time <= 0 then return end

	local current_fps = 1 / delta_time

	-- // smooth current FPS
	displayed_fps += (current_fps - displayed_fps) * smoothing
	currentframes_textlabel.Text = string.format("FPS: %d", math.round(displayed_fps))

	-- // maintain rolling window of last 10 frames
	table.insert(frame_deltas, delta_time)
	total_time += delta_time

	if #frame_deltas > max_samples then
		total_time -= table.remove(frame_deltas, 1)
	end

	-- // average FPS over last 10 frames
	local avg_dt = total_time / #frame_deltas
	local avg_fps = 1 / avg_dt

	averageframes_textlabel.Text = string.format("AVG FPS: %d", math.round(avg_fps))
end)