local tab; tab = {
	Name = "Employee";
	FullName = "Chronos Employee Division"; 
	GroupID = 32670126;
	Order = 3;
	Check = function(player: Player)
		return player.Team.Name == "Employee";
	end;
	Label = function(userId: number)
		return "Trainee";
	end;
	Level = function(userId: number)
		return 1;
	end;
};

return tab;