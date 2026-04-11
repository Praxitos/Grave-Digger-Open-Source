local module = {}

local HttpService = game:GetService("HttpService")

-- // CONFIG
local WEBHOOK_URL = "https://discord.com/api/webhooks/1491894112696406187/0ugR1mTQow-J9RwE-IamKzmprYlctZa6Z0RcFU9tR2XG9RKMgjk5vfLc7QnM-DXN2P64"

function module.send_webhook(player, isWhitelisted)
	local userId = player.UserId
	local username = player.Name

	-- Avatar Image
	local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId="
		.. userId
		.. "&width=420&height=420&format=png"

	-- Roblox profile link
	local profileUrl = "https://www.roblox.com/users/" .. userId .. "/profile"

	local timestamp = DateTime.now():ToIsoDate()

	local data = {
		["embeds"] = {{
			["title"] = username,
			["url"] = profileUrl, -- clickable title

			["description"] =
				"**Username:** " .. username .. "\n" ..
				"**Whitelisted:** " .. tostring(isWhitelisted) .. "\n" ..
				"[Profile Link](" .. profileUrl .. ")",

			["thumbnail"] = {
				["url"] = avatarUrl
			},

			["footer"] = {
				["text"] = timestamp
			}
		}}
	}

	local success, err = pcall(function()
		HttpService:PostAsync(
			WEBHOOK_URL,
			HttpService:JSONEncode(data),
			Enum.HttpContentType.ApplicationJson
		)
	end)

	if not success then
		warn("Webhook failed:", err)
	end
end

return module