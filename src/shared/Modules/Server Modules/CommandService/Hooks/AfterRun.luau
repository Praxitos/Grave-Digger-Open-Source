local RunService = game:GetService("RunService")

return function(registry)
	if RunService:IsClient() then return end

	registry:RegisterHook("AfterRun", function(context)
		local ServerScriptService = game:GetService("ServerScriptService")
		local WebhookService = require(ServerScriptService:WaitForChild("WebhookService"))

		-- Helper: serialize Roblox instances and tables
		local function serializeArg(arg)
			if typeof(arg) == "Instance" then
				return string.format("%s (%s)", arg.Name, arg.ClassName)
			elseif typeof(arg) == "table" then
				local t = {}
				for k, v in pairs(arg) do
					t[k] = serializeArg(v)
				end
				return t
			else
				return tostring(arg)
			end
		end

		local formattedArgs = {}
		for i, arg in ipairs(context.Args or {}) do
			formattedArgs[i] = serializeArg(arg)
		end

		-- Build Discord embed structure
		local embed = {
			title = string.format("Command Executed: %s", context.Name or "Unknown"),
			color = context.Error and 0xFF0000 or 0x00FF00, -- red if error, green if success
			fields = {
				{
					name = "Executor",
					value = string.format("%s (UserId: %d)",
						(context.Executor and context.Executor:IsA("Player") and context.Executor.Name) or "Server",
						(context.Executor and context.Executor:IsA("Player") and context.Executor.UserId) or 0
					),
					inline = true
				},
				{
					name = "Command",
					value = string.format("Raw: `%s`\nArguments: %s",
						context.RawText or "",
						#formattedArgs > 0 and table.concat(formattedArgs, ", ") or "None"
					),
					inline = false
				},
				{
					name = "Context",
					value = string.format("PlaceId: %d\nJobId: %s\nServerType: %s",
						game.PlaceId,
						game.JobId,
						RunService:IsStudio() and "Studio" or "Live"
					),
					inline = false
				},
				{
					name = "Result",
					value = context.Error and string.format("%s", tostring(context.Error)) or string.format("%s", tostring(context.Response or "Success")),
					inline = false
				},
				{
					name = "Timestamp",
					value = os.date("!%Y-%m-%d %H:%M:%S UTC", os.time()),
					inline = false
				}
			}
		}

		-- Send to webhook
		WebhookService.send("Command", { embeds = { embed } })
	end)
end
