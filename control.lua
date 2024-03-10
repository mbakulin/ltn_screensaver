disabled = "disabled"
looking_for_train = "looking_for_train"
following_train = "following_train"
transition = "transition"
controller_transition_time = 15
epsilon = 0.01

function has_value (tab, val)
    for index, value in pairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function dump(o)
	if type(o) == 'table' then
	   local s = '{ '
	   for k,v in pairs(o) do
		  if type(k) ~= 'number' then k = '"'..k..'"' end
		  s = s .. '['..k..'] = ' .. dump(v) .. ','
	   end
	   return s .. '} '
	else
	   return tostring(o)
	end
 end

function OnTick(event)
	--screensaver has never been activated, ignore event
	if global.per_player == nil then return end
	for idx, per_player in pairs(global.per_player) do
			--Check if any player is watching the screensaver
			if per_player.followed_train ~= nil then
				--Once every 1 second check if train either has left depot or heading to depot
				if event.tick % 60 == 0 then
					if per_player.followed_train.schedule.current ~= 1 and  global.per_player[idx].train_left_the_depot == false then
						global.per_player[idx].train_left_the_depot = true
						if global.debug_output ~= nil and global.debug_output then
							game.print("Train followed by player "..idx.." has left the depot")
						end
					elseif per_player.followed_train.schedule.current == 1 and per_player.train_left_the_depot == true then
						global.per_player[idx].screensaver_state = looking_for_train
						if global.debug_output ~= nil and global.debug_output then
							game.print("Train followed by player "..idx.." has finished the delivery")
						end
					end
				end
				--Check if train changed direction
				if per_player.locomotive ~= get_front_locomotive(idx) then
					--Set new target locomotive and initiate gradual transition to it
					global.per_player[idx].locomotive = get_front_locomotive(idx)
					global.per_player[idx].locomotive_transition_start_time = event.tick
				end
				--Set default target position to current locomotive. If any transitions are needed, this position will be changed
				local target_position = global.per_player[idx].locomotive.position
				local t = event.tick - per_player.train_follow_start_tick
				local T = per_player.transition_time
				--Transition is in progress. Some math here: we want to cover distance D in T ticks,
				--and do it slow at the start, fast in the middle, slow at the finish
				--So we can choose some A*sin(kt) function to determine current speed, where t is ticks from the start of the transition.
				--If we do some integration and so on, we can get speed per tick.
				--There is probably some off-by-one error here but that shouldn't matter: with high T values it's irrelevant
				--and with low T values transition is too fast to notice one-tick difference
				if t < T then
					local current_position = per_player.last_position
					local distance_x = target_position.x - current_position.x
					local distance_y = target_position.y - current_position.y
					speed = (math.cos(math.pi*t/T) - math.cos(math.pi*(t + 1)/T)) / (1 + math.cos(math.pi*t/T))
					target_position.x = current_position.x + distance_x*speed
					target_position.y = current_position.y + distance_y*speed
				else
					--Gradually transition to new "front" locomotive if needed
					if global.per_player[idx].locomotive_transition_start_time ~= nil
						and event.tick - global.per_player[idx].locomotive_transition_start_time < global.per_player[idx].locomotive_transition_time then
						local current_position = game.get_player(idx).position
						local ticks_left = global.per_player[idx].locomotive_transition_time - (event.tick - global.per_player[idx].locomotive_transition_start_time)
						target_position.x = current_position.x + (target_position.x - current_position.x) / ticks_left
						target_position.y = current_position.y + (target_position.y - current_position.y) / ticks_left
					end
				end
				game.get_player(idx).zoom_to_world(target_position)
				per_player.last_position = target_position
			end
		--end
	end
end

--Check what is the front locomotive
function get_front_locomotive(idx)
	local train = global.per_player[idx].followed_train
	local current_locomotive = global.per_player[idx].locomotive
	--Moving forward, use front_movers (should be always present)
	if train.speed > epsilon then
		return train.locomotives.front_movers[1]
	end
	--Moving backward, use back_movers (if present)
	if train.speed < -epsilon and train.locomotives.back_movers[1] ~= nil then
		return train.locomotives.back_movers[1]
	end
	--Locomotive is not chosen yet, and the train is stationary. Use front_movers
	if current_locomotive == nil and math.abs(train.speed) <= epsilon then
		return train.locomotives.front_movers[1]
	end
	--If train is stationary, use previous choice
	if math.abs(train.speed) <= epsilon then
		return current_locomotive
	end
	--Shouldn't be here, disable the screensaver before we crash
	local fake_event = {}
	fake_event.player_index = idx
	toggle_screensaver(fake_event)
end

function on_dispatcher_updated(event)
	if global.debug_output ~= nil and global.debug_output then
		game.print("Dispatcher updated")
	end
	if global.deliveries == nil then
		if global.debug_output ~= nil and global.debug_output then
			game.print("First time getting dispatcher update")
		end
		global.deliveries = event.deliveries
		return
	end
	if global.per_player ~= nil then
		for train_id, delivery in pairs(event.deliveries) do
			if not global.deliveries[train_id] then
				--get item to be delivered
				item, count = next(delivery.shipment, nil)
				train = train_id
				if global.debug_output ~= nil and global.debug_output then
					game.print("Train is scheduled to deliver "..item)
				end
				--find all players that are looking for new train to follow
				for idx, per_player in pairs(global.per_player) do
					if global.debug_output ~= nil and global.debug_output then
						game.print("checking player "..idx.." screensaver status. "..per_player.screensaver_state)
					end
					if per_player.screensaver_state == looking_for_train then
						if global.debug_output ~= nil and global.debug_output then
							game.print("player "..idx.." is looking for train")
						end
						--check if player already watched delivery of item recently
						if per_player.delivery_history_size == 0 or has_value(per_player.delivery_history, item) == false then
							--If force is incorrect, ignore the train
							if game.get_player(idx).force ~= delivery.force then
								if global.debug_output ~= nil and global.debug_output then
									game.print("forces of player "..idx.." and train do not match")
								end
								goto check_next_player
							end
							--If surfaces do not match, ignore the train
							if game.get_player(idx).surface ~= delivery.train.locomotives.front_movers[1].surface then
								if global.debug_output ~= nil and global.debug_output then
									game.print("surfaces of player "..idx.." and train do not match")
								end
								goto check_next_player
							end
							if per_player.delivery_history_size ~= 0 then
								global.per_player[idx].delivery_history[per_player.delivery_history_pointer] = item
								global.per_player[idx].delivery_history_pointer = (per_player.delivery_history_pointer + 1) % per_player.delivery_history_size
							end
							global.per_player[idx].screensaver_state = following_train
							global.per_player[idx].followed_train = delivery.train
							global.per_player[idx].locomotive = nil
							global.per_player[idx].locomotive = get_front_locomotive(idx)
							global.per_player[idx].train_left_the_depot = false
							global.per_player[idx].train_follow_start_tick = game.tick
							if global.debug_output ~= nil and global.debug_output then
								game.print("Player "..idx.." is now following train with "..item)
							end
						else
							if global.debug_output ~= nil and global.debug_output then
								game.print("player "..idx.."has recently watched delivery of "..item..", skipping train")
								game.print("player "..idx.." current delivery history size: "..per_player.delivery_history_size)
								if per_player.delivery_history_size ~= 0 then
									game.print("player "..idx.." item history:"..dump(per_player.delivery_history))
								end
							end
						end
					end
					::check_next_player::
				end
			end
		end
	end
	-- if screensaver has never been avtivated, just update deliveries table
	global.deliveries = event.deliveries
end

function OnTrainInvalidated(event)
	--screensaver has never been activated, ignore event
	if global.per_player == nil then return end
	for index, per_player in pairs(global.per_player) do
		--if something happened (killed, mined by robot or player) to the train that is being watched, disable screensaver for the player
		if per_player.followed_train ~= nil and has_value(per_player.followed_train.carriages, event.entity) then
			-- Fake pressing disable screensaver hotkey
			local fake_event = {}
			fake_event.player_index = index
			toggle_screensaver(fake_event)
		end
	end
end

function OnPlayerChangedSurface(event)
	--Screensaver has never been run before or for this player, exit
	if global.per_player == nil then return end
	local idx = event.player_index
	if global.per_player[idx] == nil then return end
	--Screensaver is not active for player, exit
	if global.per_player[idx].screensaver_state == nil or global.per_player[idx].screensaver_state == disabled then return end
	--Start looking for appropriate train, reset followed_train, set current position to player's position
	global.per_player[idx].screensaver_state = looking_for_train
	global.per_player[idx].followed_train = nil
	global.per_player[idx].locomotive = nil
	global.per_player[idx].last_position = game.get_player(idx).position
end

function toggle_screensaver(event)
	local idx = event.player_index
	if global.per_player == nil then global.per_player = {} end

	if global.per_player[idx] == nil then
		global.per_player[idx] = {}
	end

	if global.per_player[idx].screensaver_state == nil or global.per_player[idx].screensaver_state == disabled then
		game.get_player(idx).print({"turn-screensaver-on"})
		global.per_player[idx].delivery_history_size = game.players[idx].mod_settings["ltn-scr-delivery-history-size"].value
		if game.players[idx].mod_settings["ltn-scr-reset-history"].value == true or global.per_player[idx].delivery_history == nil then
			global.per_player[idx].delivery_history = {}
			for i=0,global.per_player[idx].delivery_history_size-1 do
				global.per_player[idx].delivery_history[i] = nil
			end 
			global.per_player[idx].delivery_history_pointer = 0
		end
		global.per_player[idx].transition_time = game.players[idx].mod_settings["ltn-scr-transition-time"].value
		global.per_player[idx].locomotive_transition_time = game.players[idx].mod_settings["ltn-scr-locomotive-transition-time"].value
		global.per_player[idx].screensaver_state = looking_for_train
		global.per_player[idx].followed_train = nil
		global.per_player[idx].locomotive = nil
		--save game view settings for restoring after the screesaver ends
		local game_view_settings =
				{show_controller_gui = game.get_player(idx).game_view_settings.show_controller_gui,
				show_minimap = game.get_player(idx).game_view_settings.show_minimap,
				show_research_info = game.get_player(idx).game_view_settings.show_research_info,
				show_entity_info = game.get_player(idx).game_view_settings.show_entity_info,
				show_alert_gui = game.get_player(idx).game_view_settings.show_alert_gui,
				update_entity_selection = game.get_player(idx).game_view_settings.update_entity_selection,
				show_rail_block_visualisation = game.get_player(idx).game_view_settings.show_rail_block_visualisation,
				show_side_menu  = game.get_player(idx).game_view_settings.show_side_menu,
				show_map_view_options = game.get_player(idx).game_view_settings.show_map_view_options,
				show_quickbar = game.get_player(idx).game_view_settings.show_quickbar,
				show_shortcut_bar = game.get_player(idx).game_view_settings.show_shortcut_bar}
		global.per_player[idx].game_view_settings = game_view_settings
		--Turn off the gui: set gui variable to on and send fake event
		global.per_player[idx].gui_is_on = true
		local event = {}
		event.player_index = idx
		toggle_gui(event)
		global.per_player[idx].last_position = game.get_player(idx).position
		game.get_player(idx).spectator = true
	else
		game.get_player(idx).print({"turn-screensaver-off"})
		global.per_player[idx].screensaver_state = disabled
		global.per_player[idx].followed_train = nil

		--restore game view settings
		if global.per_player[idx].game_view_settings ~= nil then
			game.get_player(idx).game_view_settings = global.per_player[idx].game_view_settings
		end
		game.get_player(idx).spectator = false
		game.get_player(idx).close_map()
	end
end

function toggle_gui(event)
	local idx = event.player_index
	--screensaver has never been activated, ignore keypress
	if global.per_player == nil then
		return
	end

	--screensaver has never been activated by this player, ignore keypress
	if global.per_player[idx] == nil then
		return
	end

	--Screensaver for the current player is not active, ignore keypress
	if global.per_player[idx].screensaver_state == disabled then
		return
	end

	if global.per_player[idx].gui_is_on == nil or global.per_player[idx].gui_is_on == true then
		disabled_game_view_settings =
			{show_controller_gui = false,
			show_minimap = false,
			show_research_info = false,
			show_entity_info = game.get_player(idx).game_view_settings.show_entity_info ,
			show_alert_gui = false,
			update_entity_selection = false,
			show_rail_block_visualisation = false,
			show_side_menu  = false,
			show_map_view_options = false,
			show_quickbar = false,
			show_shortcut_bar = false}
		game.get_player(idx).game_view_settings = disabled_game_view_settings
		--clean cursor to hide the menu, if any
		game.get_player(idx).clear_cursor()
		game.get_player(idx).clear_selected_entity()
		global.per_player[idx].gui_is_on = false
	else
		game.get_player(idx).game_view_settings = global.per_player[idx].game_view_settings
		global.per_player[idx].gui_is_on = true
	end
end

function mod_settings_changed(event)
	if event.setting == "ltn-scr-debug-output" then
		global.debug_output = settings.global["ltn-scr-debug-output"].value
	end
	if event.player_index == nil then
		return
	end
	local idx = event.player_index
	if event.setting_type ~= "runtime-per-user" then
		return
	end
	--If per player is nil, it means screensaver has never been started yet, and everything will be initialized anyway on first start	
	if global.per_player == nil then return end
	if event.setting == "ltn-scr-transition-time" then
		global.per_player[idx].transition_time = game.players[idx].mod_settings["ltn-scr-transition-time"].value
		return
	end
	if event.setting == "ltn-scr-locomotive-transition-time" then
		global.per_player[idx].locomotive_transition_time = game.players[idx].mod_settings["ltn-scr-locomotive-transition-time"].value
		return
	end
	if event.setting == "ltn-scr-delivery-history-size" then
		--Same: not initialized, can return.
		if global.per_player[idx].delivery_history == nil then
			return
		end
		local new_delivery_history_size = game.players[idx].mod_settings["ltn-scr-delivery-history-size"].value
		local old_delivery_history_size = global.per_player[idx].delivery_history_size
		local new_delivery_history = {}
		local old_delivery_history = global.per_player[idx].delivery_history
		local new_pointer = 0
		local old_pointer = global.per_player[idx].delivery_history_pointer
		--Can be done more efficiently, but I'm too lazy to make several checks for sizes and all. Anyway, settings change is a rare thing.
		if new_delivery_history_size ~= 0 and old_delivery_history_size ~= 0 then
			for i=0,old_delivery_history_size-1 do
				new_delivery_history[new_pointer] = old_delivery_history[old_pointer]
				new_pointer = (new_pointer + 1) % new_delivery_history_size
				old_pointer = (old_pointer + 1) % old_delivery_history_size
			end
		end
		global.per_player[idx].delivery_history = new_delivery_history
		global.per_player[idx].delivery_history_size = new_delivery_history_size
		global.per_player[idx].delivery_history_pointer = new_pointer
		return
	end
end

function subscribe_to_events(event)
	--Subscribe to hotkeys events
	script.on_event("pressed-screensaver-key", toggle_screensaver)
	script.on_event("pressed-screensaver-hide-gui-key", toggle_gui)
	--Subscribe to mod settings change event
	script.on_event(defines.events.on_runtime_mod_setting_changed, mod_settings_changed)
	--Subscribe to LTN schedule update events
	script.on_event(remote.call("logistic-train-network", "on_dispatcher_updated"), on_dispatcher_updated)
	--subscribe to events that can invalidate the train that is being followed by the screensaver
	script.on_event({defines.events.on_entity_died}, OnTrainInvalidated)
	script.on_event({defines.events.on_robot_pre_mined}, OnTrainInvalidated)
	script.on_event({defines.events.on_pre_player_mined_item}, OnTrainInvalidated)
	script.set_event_filter(defines.events.on_entity_died, {{filter = "rolling-stock"}})
	script.set_event_filter(defines.events.on_robot_pre_mined, {{filter = "rolling-stock"}})
	script.set_event_filter(defines.events.on_pre_player_mined_item, {{filter = "rolling-stock"}})
	--subscribe on tick events. not optimal because when screensaver is inactive it is still called but probably better for desyncs
	script.on_event({defines.events.on_tick}, OnTick)
	script.on_event({defines.events.on_player_changed_surface}, OnPlayerChangedSurface)
end

script.on_init(subscribe_to_events)
script.on_load(subscribe_to_events)