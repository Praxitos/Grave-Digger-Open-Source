--!strict

-- // Services
local InputService                      = game:GetService("UserInputService")
local RunService                        = game:GetService("RunService")
local PlayerService                     = game:GetService("PlayerService")

-- // References
local CameraClass                       = require(script.Parent.Parent.Library.Classes.CameraClass)
local Types                             = require(script.Parent.Parent.Library.Types.MainTypes)
local BaseCamera                        = setmetatable({}, { __index = CameraClass })
local LocalPlayer                       = PlayerService.LocalPlayer
local Mouse_Reference                   = LocalPlayer:GetMouse()

function BaseCamera:Start()
    -- // Locks Mouse
    InputService.MouseBehavior = Enum.MouseBehavior.LockCenter


    self.Connections = {
        RunService.Heartbeat:Connect(function()
            self:Update()
        end),
    }

    -- // When mouse moves left/right, move the character rotation aswell.
    Mouse_Reference.Move:Connect(function()
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
        local mouseDelta = Vector2.new(InputService:GetMouseDelta().X, 0)
        local rotationSpeed = 0.1
        LocalPlayer.Character.HumanoidRootPart.CFrame *= CFrame.Angles(0, math.rad(-mouseDelta.X * rotationSpeed), 0)
    end)
end

function BaseCamera:End()

end

function BaseCamera:Update()
    local offset = LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 5, -10)
    workspace.CurrentCamera.CFrame = offset
end

function BaseCamera.new(cameraInfo: Types.Camera_Type)
    local self = CameraClass.new(cameraInfo) 
    setmetatable(self, { __index = BaseCamera })  
    return self
end

-- Example usage
local myCameraInfo: Types.Camera_Type = {
    name = "BasicCamera",
    priority = 1,
    Connections = {},
}

local myCamera = BaseCamera.new(myCameraInfo)
myCamera:Start() 
myCamera:End() 

return myCamera