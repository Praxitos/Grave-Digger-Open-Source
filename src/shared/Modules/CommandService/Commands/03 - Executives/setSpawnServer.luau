return function (context, spawnValue)
	local executorposition = context.Executor.Character.HumanoidRootPart.Position
	
	spawnValue[1].Value = executorposition
	return ("Spawn location %s has been set."):format(spawnValue[1].Name)
end