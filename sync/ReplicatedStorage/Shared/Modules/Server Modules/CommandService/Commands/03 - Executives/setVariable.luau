return {
	Name = "setVariable";
	Aliases = {""};
	Description = "Sets a specific game variable.";
	Group = "3";
	Args = {
		{
			Type = "variable";
			Name = "Variable";
			Description = "Hinge to be set.";
		},
		
		{
			Type = "properties";
			Name = "Property";
			Description = "The specific property type.";
		},
		
		{
			Type = "string";
			Name = "Value";
			Description = "Value to set the property to.";
		},
	};
}