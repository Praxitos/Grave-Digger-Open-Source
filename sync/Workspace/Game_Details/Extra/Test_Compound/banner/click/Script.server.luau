script.Parent.clicker.MouseClick:Connect(function(player)
	if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and player.Character:FindFirstChildOfClass("Tool") == nil then
		
		workspace.remotes.serverEvent:Fire("raise_flag",player,script.Parent.Parent)
	end
	
end)