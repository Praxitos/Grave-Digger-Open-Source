local module = {}

-------------------
-- @Praxitos
-- Primary Camera Service Handler
-------------------

-- // References 

-- Services
local replicatedstorage_service                 = game:GetService("ReplicatedStorage")
local player_service                            = game:GetService("Players")
local workspace_service                         = game:GetService("Workspace")

-- Constants
local library_folder                            = replicatedstorage_service.Shared.Library
local externals_folder                          = library_folder.Externals
local typechecker_module                        = require(externals_folder.TypeChecker)
local maintypes_module                          = require(library_folder.Types.MainTypes)

-- Variables
local current_camera_module                    = nil



-- // Functions

-- starter check
local function check_cameras()
    for childname, child in pairs(script:GetChildren()) do
        if not typechecker_module.new(maintypes_module.Camera_Type)(child) then
            warn("[CAMERASERVICE::] CameraModule: ", childname, "Fails the type check!")
        end
    end
end


-- starter module
function module.start_module()
    if game:GetService("RunService"):IsServer() then
        return
    end


    check_cameras()

    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
end

-- switch camera module
function module.switch_camera(target_camera_name:string, abrupt_change:boolean)
    local target_camera_module = script:FindFirstChild(target_camera_name)
    if not target_camera_module then
        warn("[CAMERASERVICE::] No Camera Module Found with the name: ", target_camera_name)
        return
    end

    local target_camera_module_required: maintypes_module.Camera_Type = require(target_camera_module)
    if target_camera_module_required.priority < (current_camera_module and require(current_camera_module).priority or 0) then
        warn("[CAMERASERVICE::] Target Camera Module: ", target_camera_name, " has a lower priority than the current camera module.")
        return
    end
    

    if current_camera_module then
        if abrupt_change then
            current_camera_module:Cut()
        else
            current_camera_module:End()
        end
    end

    current_camera_module = require(target_camera_module)
    current_camera_module:Start()
end



return module