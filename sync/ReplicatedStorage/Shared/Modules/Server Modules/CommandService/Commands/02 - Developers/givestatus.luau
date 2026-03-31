return {
	Name = "givestatus";
	Aliases = {""};
	Description = "Force-Gives you a status";
	Group = "2";
	Args = {
		{
			Type = "players";
			Name = "Players";
			Description = "To receive the designated tools.";
		},

		{
			Type = "statuses";
			Name = "Status Names";
			Description = "The specific status name, bypasses restrictions.";
		},
	};
}