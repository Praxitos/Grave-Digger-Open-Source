return {
	Name = "removestatus";
	Aliases = {""};
	Description = "Force-Removes you a status";
	Group = "2";
	Args = {
		{
			Type = "players";
			Name = "Players";
			Description = "To Remove the designated tools.";
		},

		{
			Type = "statuses";
			Name = "Status Names";
			Description = "The specific status name, bypasses restrictions.";
		},
	};
}