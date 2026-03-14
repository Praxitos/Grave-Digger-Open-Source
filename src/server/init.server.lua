------------------
-- // Praxitos
-- // Primary Server Setup Handler
------------------

-- // Variable References
local replicatedstorage_service     = game:GetService("ReplicatedStorage")
local modules_folder                = replicatedstorage_service.Shared.Modules

-- module to startup/run
local commandservice_module         = require(modules_folder.CommandService)
local dataservice_module            = require(modules_folder.DataService)


-- start modules
commandservice_module.start_module()
dataservice_module.start_module()


