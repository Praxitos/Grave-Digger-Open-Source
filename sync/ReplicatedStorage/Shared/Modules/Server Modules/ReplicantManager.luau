local module = {}

local replicant_folder = game:GetService("ReplicatedStorage").Shared.Library.Events.Replicant_Communication
local fastcast_replicant = replicant_folder.FastCast_Connection
local vfx_replicant = replicant_folder.VFX_Connection
local sfx_replicant = replicant_folder.SFX_Connection
local texture_replicant = replicant_folder.Texture_Connection

function module.start_module()
	fastcast_replicant.OnServerEvent:Connect(function(...)
		fastcast_replicant:FireAllClients(...)
	end)
	
	vfx_replicant.OnServerEvent:Connect(function(...)
		vfx_replicant:FireAllClients(...)
	end)
	
	sfx_replicant.OnServerEvent:Connect(function(...)
		sfx_replicant:FireAllClients(...)
	end)
	
	texture_replicant.OnServerEvent:Connect(function(...)
		texture_replicant:FireAllClients(...)
	end)
end
return module
