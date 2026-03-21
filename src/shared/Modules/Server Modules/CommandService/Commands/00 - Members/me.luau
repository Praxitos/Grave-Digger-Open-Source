local Players = game:GetService("Players")

return {
	Name = "me";
	Aliases = {};
	Description = "Displays the current player's name.";
	Group = "0";
	Args = {};

	ClientRun = function()
		return Players.LocalPlayer.Name
	end
}