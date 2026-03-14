-- spawnlocations

return {
	Name = "setSpawn";
	Aliases = {""};
	Description = "Sets a specific spawn location.";
	Group = "8";
	Args = {
		{
			Type = "spawnlocations";
			Name = "Spawn";
			Description = "Spawn group to be set";
		},
	};
}
