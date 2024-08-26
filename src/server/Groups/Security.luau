local tab; tab = {
	Name = "Security";
	FullName = "Chronos Security Operations"; 
	GroupID = 15442918;
	Order = 1;
	Check = function(player: Player)
		return player.Team.Name == "Security";
	end;
	Label = function(userId: number)
		return "Officer";
	end;
	Level = function(userId: number)
		return 1;
	end;
};

return tab;