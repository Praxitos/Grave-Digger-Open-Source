return {
	Name = "wipedata";
	Aliases = {""};
	Description = "Wipes data, or specific category.";
	Group = "2";
	Args = {
		{
			Type = "players";
			Name = "Player to Wipe";
			Description = "Wipes the specific player's data.";
		},

		{
			Type = "boolean";
			Name = "wipetype";
			Description = "True to wipe all, false to wipe purely characterdata.";
		},
	};
}