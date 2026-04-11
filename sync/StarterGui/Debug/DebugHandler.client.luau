local run_service = game:GetService("RunService")
local Players = game:GetService("Players")

local debug_screenui = script.Parent
local holder_frame = debug_screenui.Holder

----------------------------------------------------------------
-- FPS UI
----------------------------------------------------------------
local fps_frame = holder_frame.FPS
local fps_tablegraph = fps_frame.Table
local fps_button = fps_frame.Button
local averageFPS = fps_frame.AverageFPS
local currentFrames = fps_frame.CurrentFrames
local fps_graph_text = fps_frame.Graph
local fps_example = fps_tablegraph.Bars.Example

----------------------------------------------------------------
-- PING UI
----------------------------------------------------------------
local ping_frame = holder_frame.Ping
local ping_tablegraph = ping_frame.Table
local ping_button = ping_frame.Button
local averagePing = ping_frame.AveragePing
local currentPing = ping_frame.CurrentPing
local ping_graph_text = ping_frame.Graph
local ping_example = ping_tablegraph.Bars.Example

-- // FPS STATE
local displayed_fps = 60
local fps_smoothing = 0.15

local frame_deltas = {}
local max_samples = 50
local total_time = 0

local fps_history = {}
local fps_max_history = 60
local fps_frame_counter = 0


-- // PING STATE
local displayed_ping = 50
local ping_smoothing = 0.15

local ping_samples = {}
local ping_max_samples = 50
local ping_total = 0

local ping_history = {}
local ping_max_history = 60
local ping_frame_counter = 0


-- // UI colors
local Colors = {
	Green = Color3.fromRGB(0, 170, 0),
	Yellow = Color3.fromRGB(255, 140, 0),
	Red = Color3.fromRGB(255, 38, 38),
}


local function get_ping()
	return Players.LocalPlayer:GetNetworkPing() * 1000
end


run_service.RenderStepped:Connect(function(delta_time)
	if delta_time <= 0 then return end

	----------------------------------------------------------------
	-- FPS
	----------------------------------------------------------------
	local current_fps = 1 / delta_time

	displayed_fps += (current_fps - displayed_fps) * fps_smoothing
	currentFrames.Text = string.format("Fps: %d", math.round(displayed_fps))

	table.insert(frame_deltas, delta_time)
	total_time += delta_time

	if #frame_deltas > max_samples then
		total_time -= table.remove(frame_deltas, 1)
	end

	local avg_dt = total_time / #frame_deltas
	local avg_fps = 1 / avg_dt

	averageFPS.Text = string.format("Avg. Fps: %d", math.round(avg_fps))


	----------------------------------------------------------------
	-- PING
	----------------------------------------------------------------
	local current_ping = get_ping()

	displayed_ping += (current_ping - displayed_ping) * fps_smoothing
	currentPing.Text = string.format("Ping: %dms", math.round(displayed_ping))

	table.insert(ping_samples, current_ping)
	ping_total += current_ping

	if #ping_samples > ping_max_samples then
		ping_total -= table.remove(ping_samples, 1)
	end

	local avg_ping = ping_total / #ping_samples
	averagePing.Text = string.format("Avg. Ping: %dms", math.round(avg_ping))


	----------------------------------------------------------------
	-- COLORS
	----------------------------------------------------------------
	local fps_color = Colors.Green
	if displayed_fps < 30 then
		fps_color = Colors.Yellow
	elseif displayed_fps < 20 then
		fps_color = Colors.Red
	end

	currentFrames.TextColor3 = fps_color
	averageFPS.TextColor3 = fps_color


	local ping_color = Colors.Green
	if displayed_ping > 120 then
		ping_color = Colors.Yellow
	elseif displayed_ping > 200 then
		ping_color = Colors.Red
	end

	currentPing.TextColor3 = ping_color
	averagePing.TextColor3 = ping_color


	----------------------------------------------------------------
	-- FPS GRAPH DATA
	----------------------------------------------------------------
	table.insert(fps_history, current_fps)

	if #fps_history > fps_max_history then
		table.remove(fps_history, 1)
	end

	fps_frame_counter += 1
	if fps_frame_counter >= 60 then
		fps_frame_counter = 0

		for _, child in ipairs(fps_tablegraph:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local max_fps = 1
		for _, fps in ipairs(fps_history) do
			max_fps = math.max(max_fps, fps)
		end

		for i, fps in ipairs(fps_history) do
			local bar = fps_example:Clone()
			bar.Visible = true
			bar.Parent = fps_tablegraph

			local scale = math.clamp(fps / max_fps, 0, 1)
			local width = (1 / fps_max_history) * 0.85

			bar.Size = UDim2.new(width, 0, scale, 0)
			bar.Position = UDim2.new((i - 1) / fps_max_history, 0, 1 - scale, 0)

			if fps < 20 then
				bar.BackgroundColor3 = Colors.Red
			elseif fps < 45 then
				bar.BackgroundColor3 = Colors.Yellow
			else
				bar.BackgroundColor3 = Colors.Green
			end
		end
	end


	----------------------------------------------------------------
	-- PING GRAPH DATA
	----------------------------------------------------------------
	table.insert(ping_history, current_ping)

	if #ping_history > ping_max_history then
		table.remove(ping_history, 1)
	end

	ping_frame_counter += 1
	if ping_frame_counter >= 60 then
		ping_frame_counter = 0

		for _, child in ipairs(ping_tablegraph:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local max_ping = 1
		for _, p in ipairs(ping_history) do
			max_ping = math.max(max_ping, p)
		end

		for i, p in ipairs(ping_history) do
			local bar = ping_example:Clone()
			bar.Visible = true
			bar.Parent = ping_tablegraph

			local normalized = math.log10(p + 1) / math.log10(max_ping + 1)
			local scale = math.clamp(normalized, 0, 1)
			scale = math.max(scale, 0.02)

			local width = (1 / ping_max_history) * 0.85

			bar.Size = UDim2.new(width, 0, scale, 0)
			bar.Position = UDim2.new((i - 1) / ping_max_history, 0, 1 - scale, 0)

			if p > 180 then
				bar.BackgroundColor3 = Colors.Red
			elseif p > 100 then
				bar.BackgroundColor3 = Colors.Yellow
			else
				bar.BackgroundColor3 = Colors.Green
			end
		end
	end
end)


fps_button.Activated:Connect(function()
	fps_tablegraph.Visible = not fps_tablegraph.Visible
end)

ping_button.Activated:Connect(function()
	ping_tablegraph.Visible = not ping_tablegraph.Visible
end)