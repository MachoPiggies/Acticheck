local tab; tab = {
	Name = "Defectors";
	FullName = "The Red Cooperative"; 
	GroupID = 16565852;
	Order = 2;
	Check = function(player: Player)
		return player.Team.Name == "Defectors";
	end;
	Label = function(userId: number)
		return "Defector";
	end;
	Level = function(userId: number)
		return 1;
	end;
};

return tab;