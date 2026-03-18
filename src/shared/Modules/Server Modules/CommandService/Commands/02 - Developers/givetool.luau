return {
	Name = "givetool";
	Aliases = {""};
	Description = "Force-Gives you a tool";
	Group = "2";
	Args = {
		{
			Type = "players";
			Name = "Players";
			Description = "To receive the designated tools.";
		},

		{
			Type = "classes";
			Name = "Item Name";
			Description = "The specific item/weapon's name, bypasses restrictions.";
		},
	};
}