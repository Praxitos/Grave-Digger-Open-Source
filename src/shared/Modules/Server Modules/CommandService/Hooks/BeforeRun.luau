return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		local cmdr_level = context.Executor:WaitForChild("PlayerData"):WaitForChild("PlayerData"):WaitForChild("CMDRLevel")
		
		local command_level = context.Group or 0
		
		if tonumber(command_level) > tonumber(cmdr_level.Value) then
			return "You have: " .. "(" .. cmdr_level.Value .. ")" .. " CMDR Level. This command requires: " .. "(" .. command_level .. ")" .. " CMDR Level."
		end
		
		return
	end)
end
