local player_service = game:GetService("Players")

local whitelist_module = require(script.Ids)
local webhook = require(script.Webhook)

player_service.PlayerAdded:Connect(function(player)
	local isWhitelisted = whitelist_module[player.UserId] ~= nil

	if isWhitelisted then
		player:SetAttribute("Whitelisted", true)
	else
		player:SetAttribute("Blacklisted", false)
		player:Kick("Not whitelisted.")
	end

	webhook.send_webhook(player, isWhitelisted)
end)