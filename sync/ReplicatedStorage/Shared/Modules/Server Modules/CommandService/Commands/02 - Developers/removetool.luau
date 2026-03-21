return {
	Name = "removetool";
	Aliases = {""};
	Description = "Force-Removes a tool";
	Group = "2";
	Args = {
		{
			Type = "players";
			Name = "Players";
			Description = "To remove the designated tools from.";
		},

		{
			Type = "classes";
			Name = "Item Name";
			Description = "The specific item/weapon's name, bypasses restrictions.";
		},
	};
}