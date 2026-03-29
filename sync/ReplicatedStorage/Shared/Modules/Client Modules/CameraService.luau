--!strict
local module = {}

-------------------
-- @Praxitos
-- Primary Camera Service Handler
-------------------

-- // References 

-- Services
local replicatedstorage_service = game:GetService("ReplicatedStorage")
local player_service            = game:GetService("Players")
local workspace_service         = game:GetService("Workspace")

-- Constants
local library_folder     = replicatedstorage_service.Shared.Library
local externals_folder   = library_folder.Externals
local typechecker_module = require(externals_folder.TypeChecker)
local camera_class       = require(library_folder.Classes.Miscellanous.CameraClass)

-- Stack (LIFO)
local Cameras_Stack = {}

-- // Internal Helpers

local function get_top_camera()
	local top = Cameras_Stack[#Cameras_Stack]
	if top then
		print("[CAMERASERVICE::] Top camera is: ", top.name)
	else
		print("[CAMERASERVICE::] Cameras stack is empty.")
	end
	return top
end

local function push_camera(camera_instance)
	table.insert(Cameras_Stack, camera_instance)
	print("[CAMERASERVICE::] Pushed camera: ", camera_instance.name)
end

local function pop_camera()
	local cam = table.remove(Cameras_Stack)
	if cam then
		print("[CAMERASERVICE::] Popped camera: ", cam.name)
	else
		print("[CAMERASERVICE::] Tried to pop but stack was empty.")
	end
	return cam
end

local function find_camera_index(name: string)
	for i = #Cameras_Stack, 1, -1 do
		if Cameras_Stack[i].name == name then
			print("[CAMERASERVICE::] Found camera '", name, "' at index ", i)
			return i
		end
	end
	print("[CAMERASERVICE::] Camera not found: ", name)
	return nil
end

local function remove_camera_by_name(name: string)
	local index = find_camera_index(name)
	if not index then
		print("[CAMERASERVICE::] Cannot remove, camera not found: ", name)
		return nil, nil
	end

	local cam = table.remove(Cameras_Stack, index)
	print("[CAMERASERVICE::] Removed camera by name: ", name, " at index ", index)
	return cam, index
end

-- starter check
local function check_cameras()
	for childname, child in pairs(script:GetChildren()) do
		if not typechecker_module.new(camera_class.Camera_Type)(child) then
			warn("[CAMERASERVICE::] CameraModule: ", childname, " fails the type check!")
		else
			print("[CAMERASERVICE::] CameraModule: ", childname, " passed type check.")
		end
	end
end

-- // Core

function module.start_module()
	print("[CAMERASERVICE::] Starting Camera Service...")
	check_cameras()
	workspace_service.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	print("[CAMERASERVICE::] Set CurrentCamera.CameraType to Scriptable")

	module.switch_camera("BaseCamera")
end

-- push new camera
function module.switch_camera(target_camera_name: string, abrupt_change: boolean)
	print("[CAMERASERVICE::] Switching to camera: ", target_camera_name, " abrupt: ", abrupt_change)
	local target_camera_module = script:FindFirstChild(target_camera_name)

	if not target_camera_module then
		warn("[CAMERASERVICE::] No Camera Module Found with the name: ", target_camera_name)
		return
	end

	local target_camera_class = require(target_camera_module)
	local current_camera = get_top_camera()

	-- prevent duplicate stacking
	if current_camera and current_camera.name == target_camera_name then
		warn("[CAMERASERVICE::] Already using camera: ", target_camera_name)
		return
	end

	-- priority check
	if current_camera and target_camera_class.priority < current_camera.priority then
		warn("[CAMERASERVICE::] Target Camera Module:", target_camera_name, "has lower priority than current: ", current_camera.name)
		return
	end

	-- transition current camera out (but DO NOT remove it)
	if current_camera then
		if abrupt_change then
			print("[CAMERASERVICE::] Cutting current camera: ", current_camera.name)
			current_camera:Cut()
		else
			print("[CAMERASERVICE::] Ending current camera: ", current_camera.name)
			current_camera:End()
		end
	end

	-- instantiate new camera
	local new_camera = target_camera_class.new({
		name = target_camera_name,
		priority = target_camera_class.priority or 0
	})
	print("[CAMERASERVICE::] Instantiated new camera: ", target_camera_name)

	push_camera(new_camera)

	new_camera:Start()
	print("[CAMERASERVICE::] Started new camera: ", target_camera_name)
end

-- pop top camera
function module.end_current_camera(abrupt: boolean)
	local current_camera = pop_camera()
	if not current_camera then return end

	if abrupt then
		print("[CAMERASERVICE::] Abruptly cutting camera: ", current_camera.name)
		current_camera:Cut()
	else
		print("[CAMERASERVICE::] Ending camera: ", current_camera.name)
		current_camera:End()
	end

	local previous_camera = get_top_camera()

	if previous_camera then
		print("[CAMERASERVICE::] Restarting previous camera: ", previous_camera.name)
		previous_camera:Start()
	else
		print("[CAMERASERVICE::] No previous camera, setting CurrentCamera.CameraType to Custom")
		workspace_service.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end

-- remove ANY camera (top or middle)
function module.end_camera_by_name(camera_name: string, abrupt: boolean)
	local index = find_camera_index(camera_name)
	if not index then return end

	local is_top = (index == #Cameras_Stack)
	local removed_camera = table.remove(Cameras_Stack, index)
	print("[CAMERASERVICE::] Removed camera: ", camera_name, " from stack. Top: ", is_top)

	if is_top then
		-- behaves like normal pop
		if abrupt then
			print("[CAMERASERVICE::] Abruptly cutting removed top camera: ", removed_camera.name)
			removed_camera:Cut()
		else
			print("[CAMERASERVICE::] Ending removed top camera: ", removed_camera.name)
			removed_camera:End()
		end

		local previous_camera = get_top_camera()

		if previous_camera then
			print("[CAMERASERVICE::] Restarting previous camera: ", previous_camera.name)
			previous_camera:Start()
		else
			print("[CAMERASERVICE::] No previous camera, setting CurrentCamera.CameraType to Custom")
			workspace_service.CurrentCamera.CameraType = Enum.CameraType.Custom
		end
	else
		-- background camera → silent cleanup
		print("[CAMERASERVICE::] Ending background camera: ", removed_camera.name)
		removed_camera:End()
	end
end

-- recoil passthrough
function module.apply_recoil(vertical, horizontal)
	local current_camera = get_top_camera()
	if current_camera and current_camera.name ~= "BaseCamera" then
		print("[CAMERASERVICE::] Applying recoil to camera: ", current_camera.name, " vertical: ", vertical, " horizontal: ", horizontal)
		current_camera:ApplyRecoil(vertical, horizontal)
	else
		print("[CAMERASERVICE::] No applicable camera for recoil or camera is BaseCamera.")
	end
end

return module