local player_service = game:GetService("Players")
local whitelist_module = require(script.Ids)

player_service.PlayerAdded:Connect(function(player)
	if whitelist_module[player.UserId] then
		return
	end

	player:Kick("Not whitelisted.")
end)