return {
	Name = "kick";
	Aliases = {"boot"};
	Description = "Kicks a player or set of players.";
	Group = "3";
	Args = {
		{
			Type = "players";
			Name = "players";
			Description = "The players to kick.";
		},
	};
}