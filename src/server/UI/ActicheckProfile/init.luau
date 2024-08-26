--!nolint DeprecatedApi
client, service, Routine, Pcall, logError = nil, nil, nil, nil, nil;

return function(data, env)
	if env then
		setfenv(1, env);
	end
	
	-- Stupid Adonis bugs, see top of Server:Acticheck for information.
	if script:FindFirstChild("FixPcall") then
		if script.FixPcall.Value then
			Pcall = function(func, ...)
				local ran, err = pcall(func, ...);

				if not ran and err then
					logError(tostring(err));
				end

				return ran, err;
			end
		end
	end;
	--
	
	local Remote = client.Remote;
	
	local TitleButtons = data.TitleButtons or {};
	local Icon = data.Icon;
	local gTable = data.gTable;
	local Size = data.Size;
	local window;
	local tabFrame;
	local search;
	local doRefresh;
	local userId = data.UserId;
	
	window = client.UI.Make("Window", {
		Name = data.Name or "List";
		Title = "Activity Check";
		Icon = Icon;
		Size = Size or {400, 250};
		MinSize = {400, 250};
		RichTextSupport = data.RichTextSupport or data.SupportRichText or false;
		OnRefresh = function() if doRefresh then doRefresh() end end;
	});

	tabFrame = window:Add("TabFrame", {
		Position = UDim2.new(0, 5, 0, 5);
		Size = UDim2.new(1,-10,1,-10);
	});
	
	local homeTab, _homeBtn = tabFrame:NewTab("Home", {
		Text = "Home";
	});

	local viewportRig = script.Rig:Clone();
	local viewport; viewport = tabFrame:Add("ViewportFrame", {
		TextWrapped = true;
		Size = UDim2.new(1, -200, 1, -35);
		Position = UDim2.new(0, 5, 0, 30);
		Children = {
			{
				Class = "WorldModel";
			};
		};
	});
	
	viewportRig.Parent = viewport.WorldModel;
	
	local function updateViewport(description)
		if not description then
			viewport.CurrentCamera = nil;
			return;
		end
		
		if typeof(description) ~= "Instance" or description.ClassName ~= "HumanoidDescription" then
			local success, desc = Pcall(service.Players.GetHumanoidDescriptionFromUserId, service.Players, description, Enum.AssetTypeVerification.ClientOnly);
			if not success then
				warn("Could not load humanoid rig:", desc);
				return;
			end
			description = desc;
		end
		
		Routine(function()
			repeat
				wait();
			until viewportRig.Humanoid:IsDescendantOf(game);
			
			local success, err = Pcall(viewportRig.Humanoid.ApplyDescription, viewportRig.Humanoid, description);
			if not success then
				warn("Could not show humanoid rig:", err);
				viewport.CurrentCamera = nil;
				return;
			end
			
			viewport.CurrentCamera = service.New("Camera", {
				CFrame = CFrame.new(viewportRig.PrimaryPart.Position - Vector3.new(0, -1, 5), viewportRig.PrimaryPart.Position);
				Parent = viewport;
			});
		end);
	end
	
	local function convertSeconds(totalSeconds)
		local days = math.floor(totalSeconds / (24 * 60 * 60));
		totalSeconds = totalSeconds % (24 * 60 * 60);

		local hours = math.floor(totalSeconds / (60 * 60));
		totalSeconds = totalSeconds % (60 * 60);

		local minutes = math.floor(totalSeconds / 60);
		local seconds = totalSeconds % 60;

		return days, hours, minutes, seconds;
	end

	local function format(days, hours, minutes, seconds)
		local timeStr = "";

		if days > 0 then
			timeStr = timeStr .. string.format("%d days, ", days);
		end

		if hours > 0 then
			timeStr = timeStr .. string.format("%d hours, ", hours);
		end

		if minutes > 0 then
			timeStr = timeStr .. string.format("%d mins, ", hours);
		end

		if seconds > 0 then
			timeStr = timeStr .. string.format("%d seconds,", seconds);
		end

		if #timeStr == 0 then
			timeStr = "None";
		else
			timeStr = timeStr:sub(1, #timeStr - 1);
		end

		return timeStr;
	end
	
	local function loadGroupInfo(group, tab)
		local holder = tab:Add("Frame", {
			Name = "Information";
			Size = UDim2.new(0, 185, 1, -10);
			Position = UDim2.new(1, -190, 0, 5);
			BackgroundColor3 = Color3.fromRGB(31,31,31);
			BackgroundTransparency = 1;
		});

		holder:Add("TextLabel", {
			Position = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 0, 20);
			Text = group.FullName or group.Name;
			ToolTip = group.FullName or group.Name;
			Font = Enum.Font.SourceSansBold;
			TextTruncate = Enum.TextTruncate.AtEnd;
			BackgroundTransparency = 1;
			TextXAlignment = Enum.TextXAlignment.Left;
		});

		holder:Add("TextLabel", {
			Position = UDim2.new(0, 0, 0, 20);
			Size = UDim2.new(1, 0, 0, 20);
			Text = "<b>Level:</b> " .. (userId and group.Level or "No user");
			RichText = true;
			TextTruncate = Enum.TextTruncate.AtEnd;
			BackgroundTransparency = 1;
			TextXAlignment = Enum.TextXAlignment.Left;
		});

		holder:Add("TextLabel", {
			Position = UDim2.new(0, 0, 0, 40);
			Size = UDim2.new(1, 0, 0, 20);
			Text = "<b>Role:</b> " .. (userId and group.Label or "No user");
			ToolTip = userId and group.Label or "No user";
			RichText = true;
			TextTruncate = Enum.TextTruncate.AtEnd;
			BackgroundTransparency = 1;
			TextXAlignment = Enum.TextXAlignment.Left;
		});

		local t = userId and format(convertSeconds(group.Time)) or "No user";
		holder:Add("TextLabel", {
			Position = UDim2.new(0, 0, 0, 60);
			Size = UDim2.new(1, 0, 0, 20);
			Text = "<b>Time:</b> " .. t;
			ToolTip = t;
			RichText = true;
			TextTruncate = Enum.TextTruncate.AtEnd;
			BackgroundTransparency = 1;
			TextXAlignment = Enum.TextXAlignment.Left;
		});

		if group.GroupID then
			holder:Add("TextLabel", {
				AnchorPoint = Vector2.new(1, 1);
				Position = UDim2.new(1, 0, 1, -40);
				Size = UDim2.new(1, 0, 0, 20);
				Text = "Linked Group";
				Font = Enum.Font.SourceSansBold;
				TextTruncate = Enum.TextTruncate.AtEnd;
				BackgroundTransparency = 1;
				TextXAlignment = Enum.TextXAlignment.Right;
			});

			holder:Add("TextLabel", {
				AnchorPoint = Vector2.new(1, 1);
				Position = UDim2.new(1, 0, 1, -20);
				Size = UDim2.new(1, 0, 0, 20);
				Text = "<b>Name:</b> " .. (group.Group and group.Group.Name or "Error");
				ToolTip = group.Group and group.Group.Name or "Error";
				RichText = true;
				TextTruncate = Enum.TextTruncate.AtEnd;
				BackgroundTransparency = 1;
				TextXAlignment = Enum.TextXAlignment.Right;
			});

			holder:Add("TextLabel", {
				AnchorPoint = Vector2.new(1, 1);
				Position = UDim2.new(1, 0, 1, 0);
				Size = UDim2.new(1, 0, 0, 20);
				Text = "<b>Rank:</b> " .. (group.Group and group.Group.Role or "Error");
				ToolTip = userId and group.Group and group.Group.Role or "Error" or "No user";
				RichText = true;
				TextTruncate = Enum.TextTruncate.AtEnd;
				BackgroundTransparency = 1;
				TextXAlignment = Enum.TextXAlignment.Right;
			});
		end
		
		return holder;
	end
	
	local callback = Remote.Get("ActicheckGroups", userId);
	local groups = {};
	for _,group in callback do
		groups[group.Order] = group;
	end
	
	local tabs, buttons = {}, {};
	
	for _,group in groups do
		local tab, button = tabFrame:NewTab(group.Name, {
			Text = group.Name;
		});
		
		loadGroupInfo(group, tab);
		
		tabs[group.__internal] = tab;
		buttons[group.__internal] = button;
	end

	function doRefresh()

		callback = Remote.Get("ActicheckGroups", userId);
		groups = {};
		for _,group in callback do
			groups[group.Order] = group;
		end
		
		for id, tab in tabs do
			if not tab:FindFirstChild("Information") then continue end;
			tab:FindFirstChild("Information"):Destroy();

			loadGroupInfo(callback[id], tab);
		end
	end
	
	-- home
	do
		local updatePlayers, playerBox, playerSearchError;
		local searchTermValue = "NAME";

		homeTab:Add("Frame", {
			Name = "Background";
			Position = UDim2.new(0,5,0,5);
			Size = UDim2.new(1, -140, 1, -10);
			BackgroundColor3 = Color3.fromRGB(31,31,31);
		});

		homeTab:Add("Frame", {
			Name = "Background";
			Size = UDim2.new(0, 125, 1, -60);
			Position = UDim2.new(1, -130, 0, 30);
			BackgroundColor3 = Color3.fromRGB(31,31,31);
		});

		local menu = homeTab:Add("Frame", {
			Size = UDim2.new(1, -145, 1, -10);
			Position = UDim2.new(0, 5, 0, 5);
			BackgroundTransparency = 1;
		});

		local plrs = homeTab:Add("ScrollingFrame", {
			Name = "PlayerSearch";
			Size = UDim2.new(0, 125, 1, -60);
			Position = UDim2.new(1, -130, 0, 30);
			BackgroundTransparency = 1;
		});
		plrs:Add("UIListLayout", {SortOrder = Enum.SortOrder.Name});

		search = homeTab:Add("TextBox", {
			Name = "Search";
			Size = UDim2.new(0,125,0,20);
			Position = UDim2.new(1,-130,0,5);
			BackgroundTransparency = 0;
			BorderSizePixel = 0;
			TextColor3 = Color3.fromRGB(255,255,255);
			Text = "";
			PlaceholderText = "Search";
			TextStrokeTransparency = 0.8;
		});

		search:Add("ImageLabel", {
			Image = client.MatIcons.Search;
			Position = UDim2.new(1, -20, 0, 2);
			Size = UDim2.new(0, 16, 0, 16);
			ImageTransparency = 0.2;
			BackgroundTransparency = 1;
		});

		search:GetPropertyChangedSignal("Text"):Connect(function()
			search.Text = search.Text:sub(1,20);
			updatePlayers();
		end)

		do

			local inputBlock = false

			local binderBox; binderBox = homeTab:Add("Frame", {
				Visible = false;
				Size = UDim2.new(0, 200, 0, 150);
				Position = UDim2.new(0.5, -100, 0.5, -100);
				ZIndex = 3;
				Children = {
					{
						Class = "TextLabel";
						Text = "Player";
						Position = UDim2.new(0, 0, 0, 10);
						Size = UDim2.new(1, 0, 0, 20);
						BackgroundTransparency = 1;
						ZIndex = 4;
					};
					{
						Class = "TextLabel";
						Text = "Term";
						Position = UDim2.new(0, 0, 0, 65);
						Size = UDim2.new(1, 0, 0, 20);
						BackgroundTransparency = 1;
						ZIndex = 4;
					};
					{
						Class = "TextButton";
						Text = "Search";
						Font = Enum.Font.SourceSansBold;
						AnchorPoint = Vector2.new(1,0);
						Position = UDim2.new(1, -10, 1, -30);
						Size = UDim2.new(0.5, -20, 0, 20);
						BackgroundTransparency = 0;
						BackgroundColor3 = Color3.fromRGB(53, 53, 53);
						ZIndex = 4;
						OnClicked = function()
							local value = playerBox.Text;
							inputBlock = true;
							if value ~= "" then
								local success, data;
								if searchTermValue == "NAME" then
									success, data = Pcall(service.Players.GetUserIdFromNameAsync, service.Players, value);

									if not success then
										playerSearchError.Text = "Invalid username provided";
										delay(3, function()
											if playerSearchError.Text == "Invalid username provided" then
												playerSearchError.Text = "";
											end
										end)
										inputBlock = false;
										return;
									end
									userId = data;
								elseif searchTermValue == "USER ID" then
									success, data = Pcall(service.Players.GetNameFromUserIdAsync, service.Players, value);

									if not success then
										playerSearchError.Text = "Invalid user ID provided";
										delay(3, function()
											if playerSearchError.Text == "Invalid user ID provided" then
												playerSearchError.Text = "";
											end
										end)
										inputBlock = false;
										return;
									end
									userId = tonumber(value);
								end
								if userId then
									updatePlayers();
								end
								binderBox.Visible = false;
								menu.Visible = true;
							end
							inputBlock = false;
						end;
					};
					{
						Class = "TextButton";
						Text = "Cancel";
						Position = UDim2.new(0, 10, 1, -30);
						Size = UDim2.new(0.5, -20, 0, 20);
						BackgroundTransparency = 0;
						BackgroundColor3 = Color3.fromRGB(53, 53, 53);
						ZIndex = 4;
						OnClicked = function()
							if not inputBlock then
								playerBox.Text = "";
								inputBlock = false;
								binderBox.Visible = false;
							end
						end;
					};
				};
			});

			playerSearchError = binderBox:Add("TextLabel", {
				Position = UDim2.new(0, 0, 0, 55);
				Size = UDim2.new(1, 0, 0, 10);
				TextSize = 12;
				BackgroundTransparency = 1;
				Text = "";
				TextColor3 = Color3.new(1,0,0);
				ZIndex = 4;
			});


			playerBox = binderBox:Add("TextBox", {
				Position = UDim2.new(0, 10, 0, 35);
				Size = UDim2.new(1, -20, 0, 20);
				ClearTextOnFocus = false;
				Text = "";
				PlaceholderText = "Search";
				BackgroundColor3 = Color3.fromRGB(53, 53, 53);
				ZIndex = 4;
			});

			local searchTerm = binderBox:Add("Dropdown", {
				Size = UDim2.new(1, -20, 0, 20);
				Position = UDim2.new(0, 10, 0, 90);
				BackgroundTransparency = 0;
				BackgroundColor3 = Color3.fromRGB(52,52,52);
				Selected = "NAME";
				NoArrow = false;
				TextProperties = {
					TextTransparency = 0.5;
				};

				Options = {
					"NAME";
					"USER ID";
				};

				OnSelect = function(selection)
					searchTermValue = selection;
				end;
				ZIndex = 4;
			});
			searchTerm.Down.ZIndex = 5; -- An Adonis API oversight means these need to be changed ourselves
			searchTerm.dSelected.ZIndex = 5;

			homeTab:Add("TextButton", {
				Name = "Offline Search";
				Size = UDim2.new(0,125,0,20);
				Position = UDim2.new(1,-130,1,-25);
				BackgroundTransparency = 0;
				BorderSizePixel = 0;
				TextColor3 = Color3.fromRGB(255,255,255);
				Text = "Offline Search";
				TextStrokeTransparency = 0.8;
				OnClick = function()
					if not inputBlock then
						playerBox.Text = "";
						binderBox.Visible = true;
					end
				end;
			});
		end
		
		function updatePlayers()
			plrs:ClearAllChildren();
			plrs:Add("UIListLayout", {});
			
			updateViewport(userId);
			doRefresh();
			
			local function show(_userId)
				local player: Player? = service.Players:GetPlayerByUserId(_userId);
				local name = "";
				if player then
					name = player.Name;
				else
					local success, info = Pcall(service.Players.GetNameFromUserIdAsync, service.Players, userId);
					name = success and info or "Unknown (" .. _userId .. ")";
				end

				if name:sub(1, #search.Text):lower() ~= search.Text:lower() then return end;

				plrs:Add("TextButton", {
					Size = UDim2.new(1, 0, 0, 35);
					Text = "  " .. name;
					ToolTip = player and service.FormatPlayer(player) or nil;
					TextXAlignment = Enum.TextXAlignment.Left;
					TextColor3 = _userId == userId and Color3.fromRGB(170, 255, 255) or Color3.new(1, 1, 1);
					OnClick = function(self)
						userId = userId ~= _userId and _userId or nil;
						self.TextColor3 = _userId == userId and Color3.fromRGB(170, 255, 255) or Color3.new(1, 1, 1);
						updatePlayers();
					end;
				});
			end
			
			if userId then
				show(userId) -- Show selected first
			end
			
			for _, player in pairs(service.GetPlayers()) do
				if player.UserId == userId then continue end;
				show(player.UserId);
			end
			plrs:ResizeCanvas(false, true, false, false, 5, 0);
		end

		service.HookEvent("PlayerAdded", updatePlayers);
		service.HookEvent("PlayerRemoving", updatePlayers);
		updatePlayers();
	end
	
	for i, v in ipairs(TitleButtons) do
		window:AddTitleButton(v)
	end

	gTable = window.gTable;
	window:Ready();
	
	Routine(function()
		while gTable.Active and wait(60) and userId and service.Players:GetPlayerByUserId(userId) do
			window:Refresh();
		end
	end);
end
