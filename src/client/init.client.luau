------------------
-- // Praxitos
-- // Primary Client Setup Handler
------------------

-- // Variable References
local replicatedstorage_service     = game:GetService("ReplicatedStorage")
local modules_folder                = replicatedstorage_service.Shared.Modules

-- // Functions

-- Starts all the Modules
for _, child in pairs(modules_folder["Client Modules"]:GetChildren()) do
    local required_child = require(child)
    if required_child.start_module then
        required_child.start_module()
    end
end