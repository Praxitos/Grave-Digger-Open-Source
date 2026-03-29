-------------
-- @Praxitos
-- Handles the Menu system
-------------

local module = {}


-- // Services
local input_service = game:GetService("UserInputService")
local camera_service = require(script.Parent.CameraService)
local player_service = game:GetService("Players")

-- // Variables
local menu_camera_module = require(script.Parent.CameraService.MenuCamera)
local menu_button = Enum.KeyCode.M
local menu_boolean = false

local local_player = player_service.LocalPlayer
local menu_ui = local_player.PlayerGui:WaitForChild("Menu")

local main_menu = menu_ui.Main_Frame

-- // functions
local function set_ui()
	menu_ui.Enabled = menu_boolean
end

local function color_all_grey()
	for _, child in pairs(main_menu:GetChildren()) do
		if not child:IsA("ImageButton") then return end
		
		child.ImageColor3 = Color3.new(0,0,0)
	end
end

function module.start_module()
	print("[MENUSERVICE::] Starting Menu Service!")
	
	
	input_service.InputBegan:Connect(function(input, gps)
		if gps then return end
		
		if input.KeyCode == menu_button then
			if menu_boolean then
				menu_boolean = false
				camera_service.end_camera_by_name("MenuCamera", true)
				print("[MENUSERVICE::] Menu Closed!")
			else
				menu_boolean = true
				camera_service.switch_camera("MenuCamera", true)
				print("[MENUSERVICE::] Menu Opened!")
			end
			
			set_ui()
		end
	end)
	
	for _, button: ImageButton in pairs(main_menu:GetChildren()) do
		print("[MENUSERVICE::] Checking Button: " .. button.Name .. "")
		if not button:IsA("ImageButton") then continue end
	
		
		print("[MENUSERVICE::] Connecting Button: " .. button.Name .. "")
		button.Activated:Connect(function()
			print("[MENUSERVICE::] Switching Scene to:", button.Name)
			menu_camera_module:Switch(button.Name)
			color_all_grey()
			button.ImageColor3 = Color3.new(255,255,255)
		end)
	end
end

return module
