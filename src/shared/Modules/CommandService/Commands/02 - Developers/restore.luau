return {
	Name = "restore";
	Aliases = {""};
	Description = "Sets a player to be restored.";
	Group = "7";
	Args = {
		{
			Type = "string";
			Name = "playername";
			Description = "Specific to be restored or unrestored.";
		},

		{
			Type = "boolean";
			Name = "set";
			Description = "Shows the table of the specific store key.";
			Optional = true
		},
	};
}