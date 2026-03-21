return {
	Name = "kill";
	Aliases = {"slay"};
	Description = "Kills a player or set of players.";
	Group = "3";
	Args = {
		{
			Type = "players";
			Name = "victims";
			Description = "The players to kill.";
		},
	};
}
