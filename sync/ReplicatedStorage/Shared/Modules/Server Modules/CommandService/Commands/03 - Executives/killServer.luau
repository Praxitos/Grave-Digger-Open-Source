return function (_, players)
	for _, player in pairs(players) do
		if player.Character then
			player.Character.Humanoid.Health = 0
		end
	end

	return ("Killed %d players."):format(#players)
end