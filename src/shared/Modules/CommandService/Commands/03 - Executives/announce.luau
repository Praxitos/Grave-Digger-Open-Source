return {
	Name = "announce";
	Aliases = {"m"};
	Description = "Makes a server-wide announcement.";
	Group = "3";
	Args = {
		{
			Type = "string";
			Name = "text";
			Description = "The announcement text.";
		},
	};
}