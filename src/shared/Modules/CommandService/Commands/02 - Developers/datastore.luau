return {
	Name = "datastore";
	Aliases = {""};
	Description = "Returns the table of the specific keyed within the datastore.";
	Group = "9";
	Args = {
		{
			Type = "string";
			Name = "datastore";
			Description = "Shows the table of the specific store key.";
		},
		
		{
			Type = "string";
			Name = "key";
			Description = "Shows the table of the specific store key.";
		},
	};
}