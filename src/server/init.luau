-- Created by MachoPiggies for purpose of use by Chronos Science Corporation (CSC) and subsidiaries. License: CC BY

logError = nil;
Pcall = nil;
cPcall = nil;

-- // ** KNOWN ISSUE ** \\ --
-- There is a bug within Adonis' client module which causes an incorrect error to be reported when the Pcall function is used.
-- This means that you will sometimes see an Adonis error message such as "ERROR: HumanoidDescription" when using the Acticheck
-- UI's. I have contacted the developers of Adonis to fix this oversight, until then, the line below temporarily fixes the issue.
--
-- Pcall is something you should use when using Roblox's async methods such as GetNameFromUserIdAsync etc, this is what is
-- broken in Adonis. Adonis define their own version of Pcall which automatically reports errors to their internal log
-- accessible from ;errorlogs, this is what isn't working correctly on the client side, and is causing incorrect warnings.
--
-- Source: "oops yeah thats not right" ~ Coasterteam, Adonis Core Maintainer (via Adonis Discord: https://discord.com/channels/81902207070380032/944715691477594172/1254191002219057202)
script.UI.ActicheckProfile.FixPcall.Value = true;

local settings = {
	-- Time in seconds before group checks are re-ran, the lower this is, the higher chance it may cause server-side delay.
	-- For the most part, the delay would be small, but this is forcefully min'd at 5 to be safe. All checks are run in
	-- asynchronous threads regardless of what settings are set however. Set to 'nil' to disable the interval.
	RefreshInterval = 30;
	
	-- Determines how long results of RemoteFunctions are cached and returned. Minimum value is 20. Whilst this may show
	-- slightly out of date information for currently online players, it makes the system a whole lot faster.
	RequestCache = 20;
	
	CustomEvents = {
		GroupChange = function(refresh, Vargs)
			-- This is logic that must be written by a Chronos developer, I do not have access to Chronos resources to know
			-- specifically how to detect a group change effectively. Listen to your event here then fire the 'refresh' method
			-- with no arguments. The refresh method is thread and error safe, you do not need to pcall it yourself.
			
			-- If this event was specifically implemented correctly, it would remove the need for any of RefreshInterval to
			-- be active.
			
			-- Any Roblox events should be disconnected correctly, use service.HookEvent or service.RbxEvent to listen to events
			-- correctly please! :)
			
			-- This should work theoretically:
			
			local service = Vargs.Service;
			
			local events = {};

			service.HookEvent("PlayerAdded", function(player: Player)
				events[player.UserId] = service.RbxEvent(player:GetPropertyChangedSignal("Team"), refresh);
			end);
			
			service.HookEvent("PlayerRemoving", function(player: Player)
				local event = events[player.UserId];
				if not event then return end;
				event:Disconnect();
			end);
			
			-- It's good practice to disconnect lingering events yourself to prevent memory leaks, Adonis hooked events through
			-- service.HookEvent and service.RbxEvent wipe themselves when needed, therefore you don't need to do it yourself
			-- for those ones.
		end;
	};
	
	-- Time in seconds before the cache is automatically saved to the datastore. The server will do this automatically during
	-- a server close, however will not during a server crash, this method stands as a fail safe for that. Default is 5 minutes.
	-- All saves are asynchronous apart from game close saves, and the save has a hard minimum interval of 2 mins. Set to nil
	-- to disable the interval.
	SaveInterval = 300;
}

--=====================================--

return function(Vargs)
	local server, service = Vargs.Server, Vargs.Service;
	
	local acticheck;
	
	local Cache: {[number]: {[string]: {Start: number, End: number}}};
	
	local Operations, Utility = {
		Push = function()
			local data = {};
			
			for userId, groups: {[string]: {Start: number, End: number?}} in Cache do
				data[userId] = {};
				
				for groupId, amount: {Start: number, End: number?} in groups do
					local _end = amount.End and amount.End >= 0 and amount.End or os.time();
					local difference = _end - amount.Start;
					
					Cache[userId][groupId].Start = os.time();
					Cache[userId][groupId].End = -1;
					
					data[userId][groupId] = difference;
				end
			end
			
			for userId, groups in data do
				for groupId, delta in groups do
					local success, err = Pcall(acticheck.IncrementDatastoreRecord, "User_" .. userId, delta, "group/" .. groupId, userId);
					if not success then
						warn("Could not update Acticheck record for", userId, "for group", groupId, ":", err);
					end
				end
			end
		end;
		
		Refresh = function(player: Player?)
			local function refreshPlayer(player: Player)
				local groups = {};
				for _,group in server.Variables.Acticheck.Groups do
					local success, value = Pcall(group.Check, player);
					if not success then
						warn("Could not check if player", player, "was in group", group.Name, "(" .. group.__internal .. ") as:", value);
						continue;
					end
					
					if value then groups[group.__internal] = group end;
				end
				
				if not Cache[player.UserId] then
					Cache[player.UserId] = {};
				end
				
				-- Ignore groups already being tracked, detect the ones that are no longer being tracked and remove them
				for _,group in Cache[player.UserId] do
					if not groups[group.__internal] then
						Cache[player.UserId][group.__internal].End = os.time(); -- End it if not active
						continue;
					end;
					Cache[player.UserId][group.__internal].End = -1; -- Resume otherwise, just as a precaution
					groups[group.__internal] = nil;
				end
				
				-- Enlist the others joined since the last check
				for _,group in groups do
					Cache[player.UserId][group.__internal] = {
						Start = os.time();
						End = -1;
						__origin = os.time();
					}
					groups[group.__internal] = nil;
				end
			end
			
			if player then
				refreshPlayer(player);
				return;
			end
			
			for _,player in service.GetPlayers() do
				refreshPlayer(player);
			end
		end;
	}, {
		DsCache = {};
		
		GetDatastoreRecord = function(key, scope, default, setWhenNotProvided, userId)
			assert(key, "No key provided");
			
			local datastore = acticheck.DsCache[scope or "default"];
			local success;
			
			if not datastore then
				local args = {service.DataStoreService.GetDataStore, service.DataStoreService, "Acticheck"};
				if scope then table.insert(args, scope) end;
				
				success, datastore = Pcall(unpack(args)); 
				if not success or not datastore then
					error("Could not load Acticheck datastore with scope " .. (scope or "default") .. ": " .. datastore);
				end
				
				acticheck.DsCache[scope or "default"] = datastore;
			end
			
			local record;
			success, record = Pcall(datastore.GetAsync, datastore, key, service.New("DataStoreGetOptions", {UseCache = false}));
			if not success then
				error("Could not get record from Acticheck datastore with scope " .. (scope or "default") " using key " .. key .. ":" .. record);
			end
			
			if not record and default and setWhenNotProvided then
				acticheck.SetDatastoreRecord(key, default, scope, userId);
				return default;
			end
			
			if record and default and typeof(record) == "table" and typeof(default) == "table" then
				local c = table.clone(default);
				for i,v in record do
					c[i] = v;
				end
				return c;
			end
			
			return record or default;
		end;
		
		-- Because servers are not updating the same key at the same time, there isn't much need to use UpdateAsync over SetAsync here
		SetDatastoreRecord = function(key, data, scope, userId)
			assert(key, "No key provided");

			local datastore = acticheck.DsCache[scope or "default"];
			local success;

			if not datastore then
				local args = {service.DataStoreService.GetDataStore, service.DataStoreService, "Acticheck"};
				if scope then table.insert(args, scope) end;

				success, datastore = Pcall(unpack(args)); 
				if not success or not datastore then
					error("Could not load Acticheck datastore with scope " .. (scope or "default") .. ": " .. datastore);
				end

				acticheck.DsCache[scope or "default"] = datastore;
			end
			
			local result;
			local args = data and {datastore.SetAsync, datastore, key, data} or {datastore.RemoveAsync, datastore, key};
			if data and userId then
				table.insert(args, {userId}); -- Helps with player data removals and finding data (GDPR)
			end
			success, result = Pcall(unpack(args));
			if not success then
				error("Could not update record from Acticheck datastore with scope " .. (scope or "default") .. " using key " .. key .. ": " .. result);
			end
			
			return result;
		end;
		
		IncrementDatastoreRecord = function(key, delta, scope, userId)
			assert(key, "No key provided");
			assert(delta, "No delta provided");

			local datastore = acticheck.DsCache[scope or "default"];
			local success;

			if not datastore then
				local args = {service.DataStoreService.GetDataStore, service.DataStoreService, "Acticheck"};
				if scope then table.insert(args, scope) end;

				success, datastore = Pcall(unpack(args)); 
				if not success or not datastore then
					error("Could not load Acticheck datastore with scope " .. (scope or "default") .. ": " .. datastore);
				end

				acticheck.DsCache[scope or "default"] = datastore;
			end
			
			local result;
			local args = {datastore.IncrementAsync, datastore, key, delta};
			if userId then
				table.insert(args, {userId}); -- Helps with player data removals and finding data (GDPR)
			end
			
			success, result = Pcall(unpack(args));
			if not success then
				error("Could not update record from Acticheck datastore with scope" .. (scope or "default") .. "using key" .. key .. ":\n" .. result);
			end

			return result;
		end;
	};
	
	acticheck = setmetatable({
		Cache = {};
		AdminAdvisories = {};
		
		Load = function()
			
			-- Move custom UIs into UI load pre-client transfer
			for _, ui in pairs(script.UI:GetChildren()) do
				ui.Parent = server.Client.UI.Default;
			end
			
			-- Load transient variables into the Variables module 
			server.Variables.Acticheck = {
				Groups = setmetatable({}, {
					__index = function(tab, index)
						if typeof(index) ~= "string" then return nil end;
						local _index = index:lower():gsub(" ", "_");
						if index == _index then return nil end;
						
						return tab[_index]
					end;
				});
			};
			
			server.Commands.Acticheck = {
				Prefix = server.Settings.Prefix;
				Commands = {"acticheck", "groupprofile", "profile", "gp", "playertime"};
				Args = {"player"};
				Description = "Grabs a players activity in defined groups in the game";
				AdminLevel = "Moderators"; -- Change this to what suits
				Function = function(player, args)
					local userId;
					if #args > 0 then
						local success, _userId = Pcall(service.Players.GetUserIdFromNameAsync, service.Players, args[1]);
						assert(success, "Could not find player by the name of " .. args[1] .. ". Make sure it is an exact players name!");
						userId = _userId;
					end

					server.Remote.MakeGui(player, "ActicheckProfile", {
						UserId = userId;
					});
				end
			};
			
			acticheck.HookRemotes();
			acticheck.LoadGroups();
			
			-- // Runners \\ --
			
			for name, event in settings.CustomEvents do
				-- Running this refresh async
				local success, err = Pcall(event, function() service.TrackTask("Thread: Acticheck Refresh", acticheck.Refresh) end, Vargs);
				if not success then
					warn("Unable to register event:", name, "as:", err);
				end
			end
			
			if settings.RefreshInterval then
				service.StartLoop("Acticheck:Refresh", math.max(5, settings.RefreshInterval), acticheck.Refresh, true);
			end
			
			if settings.SaveInterval then
				service.StartLoop("Acticheck:Save", math.max(120, settings.SaveInterval), function()
					local success, err = Pcall(acticheck.Push);
					if not success then
						warn("Failed to push Acticheck activity data during interval save:", err);
					end
				end, true);
			end
			
			game:BindToClose(function()
				local success, err = Pcall(acticheck.Push);
				if not success then
					warn("Failed to push Acticheck activity data during server close:", err);
				end
			end);
			
			service.HookEvent("PlayerAdded", function(player: Player)
				if not server.Admin.CheckAdmin(player) then return end;
				for _,notif in acticheck.AdminAdvisories do
					server.Remote.MakeGui(player, "Notification", notif);
					wait(.1);
				end
			end);
		end;
		
		HookRemotes = function()
			local requestCache = {};
			
			server.Remote.Returnables.ActicheckGroups = function(player: Player, data)
				local command = server.Commands.Acticheck;

				if command and server.Admin.CheckComLevel(server.Admin.GetLevel(player), command.AdminLevel) then
					local tab = service.DeepCopy(server.Variables.Acticheck.Groups);
					
					local success, info;
					
					if not data[1] then
						if requestCache["groups"] and os.time() - requestCache["groups"].Time < math.max(settings.RequestCache, 10) then
							return requestCache["groups"].Data;
						end
						
						for _,group in pairs(tab) do
							success, info = Pcall(service.GroupService.GetGroupInfoAsync, service.GroupService, group.GroupID);
							if not success then return group end;
							group.Group = info;
						end
						
						requestCache["groups"] = {Data = tab, Time = os.time()};
						return tab;
					end
					

					if requestCache["groups/" .. data[1]] and os.time() - requestCache["groups/" .. data[1]].Time < math.max(settings.RequestCache, 10) then
						return requestCache["groups/" .. data[1]].Data;
					end
					
					local target = service.Players:GetPlayerByUserId(data[1]);
					for _,group in pairs(tab) do
						if target then
							success, info = Pcall(group.Check, target);
							group.Check = success and info or false;
						else
							group.Check = nil;
						end
						
						success, info = Pcall(group.Label, data[1]);
						group.Label = success and info or "Error";
						
						success, info = Pcall(group.Level, data[1]);
						group.Level = success and info or -1;
						
						if group.GroupID then
							success, info = Pcall(service.GroupService.GetGroupInfoAsync, service.GroupService, group.GroupID);
							if not success then return group end;
							group.Group = info;
								
							success, info = Pcall(player.GetRoleInGroup, player, group.GroupID);
							group.Group.Role = success and info or "Error";
						end
						
						group.Time = acticheck.GetDatastoreRecord("User_" .. data[1], "group/" .. group.__internal, 0, true, data[1]);
					end

					requestCache["groups/" .. data[1]] = {Data = tab, Time = os.time()};
					return tab;
				else
					server.Anti.Detected(player, "Kick", "Restricted Remote Data (r10004)");
				end

				return nil;
			end
		end;
		
		LoadGroups = function()
			
			for _, child in pairs(script.Groups:GetChildren()) do
				if not child:IsA("ModuleScript") then continue end;
				
				local success, template = Pcall(require, script.Deps.DefaultGroup); -- Check to see if anyone has been touching
				if not success then
					table.insert(acticheck.AdminAdvisories, {
						Title = "Acticheck: Catastrophic Error";
						Message = "DefaultGroup load failure!";
						Icon = server.MatIcons["Error"];
						Time = 15;
						OnClick = server.Core.Bytecode("client.Remote.Send('ProcessCommand','" .. server.Settings.Prefix .. "logs')");
					});
					warn("DefaultGroup could not be required, please undo any changes you have made or fix any apparent errors:", template);
					return;
				end
				template = service.DeepCopy(template);
				
				local group;
				success, group = Pcall(require, child);
				if not success then
					table.insert(acticheck.AdminAdvisories, {
						Title = "Acticheck: Error";
						Message = "Could not load group: " .. child.Name;
						Icon = server.MatIcons["Error"];
						Time = 15;
						OnClick = server.Core.Bytecode("client.Remote.Send('ProcessCommand','" .. server.Settings.Prefix .. "logs')");
					});
					table.insert(acticheck.AdminAdvisories, "Error: Could not load group: " .. child.Name);
					warn("Could not load group:", child.Name, "as:", group);
					continue;
				end
				
				for i,v in group do
					template[i] = v;
				end
				
				template.__internal = template.Name:lower():gsub(" ", "_");
				
				server.Variables.Acticheck.Groups[template.__internal] = template;
			end;
		end;
	}, {
		__index = function(tab, index)
			return Operations[index] or Utility[index];
		end;
	});
	
	Cache = acticheck.Cache;
	
	service.TrackTask("Activity Checker Load", acticheck.Load);
	--[[
	Load this in an async Adonis thread to not block up the Adonis stack during load, this should really be done for
	all plugins
	]] --
end