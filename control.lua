disabled = "disbled"
looking_for_train = "looking_for_train"
following_train = "following_train"

function has_value (tab, val)
    for index, value in ipairs(tab) do
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
	for idx, per_player in ipairs(global.per_player) do
		if per_player.followed_train ~= nil then
			if event.tick % 120 == 0 then
				if per_player.followed_train.schedule.current ~= 1 then
					global.per_player[idx].train_left_the_depot = true
				elseif per_player.train_left_the_depot == true then
					global.per_player[idx].screensaver_state = looking_for_train
				end
			end
			game.get_player(idx).teleport(per_player.followed_train.locomotives.front_movers[1].position)
		end
	end
end

function OnWaypointReached(event)
	local idx = event.player_index
	local per_player = global.per_player[idx]
	if per_player.followed_train ~= nil then
		if game.tick - per_player.train_follow_start_tick > 10 then
			script.on_event({defines.events.on_tick}, OnTick)
			local alt_mode = game.get_player(idx).game_view_settings.show_entity_info 
			game.get_player(idx).set_controller{type=defines.controllers.ghost}
			game_view_settings =
				{show_controller_gui = false,
				show_minimap = false,
				show_research_info = false,
				show_entity_info = alt_mode,
				show_alert_gui = false,
				update_entity_selection = false,
				show_rail_block_visualisation = false,
				show_side_menu  = false,
				show_map_view_options = false,
				show_quickbar = false,
				show_shortcut_bar = false}
			game.get_player(idx).game_view_settings = game_view_settings
			game.get_player(idx).teleport(per_player.followed_train.locomotives.front_movers[1].position)
		end
	end
end

function OnDispatcherUpdated(event)
	if table_size(event.train.schedule.records) == 1 then
		return
	end

	local item = nil
	for index, wait_condition in pairs(event.train.schedule.records[2].wait_conditions) do
		if wait_condition.condition ~= nil then
			item = 	wait_condition.condition.first_signal.name
			break
		end
	end
	if item == nil then
		return
	end


	for idx, per_player in ipairs(global.per_player) do
		if per_player.screensaver_state == looking_for_train then
			if has_value(per_player.delivery_history, item) == false then
				global.per_player[idx].delivery_history[per_player.delivery_history_pointer] = item
				global.per_player[idx].delivery_history_pointer = (per_player.delivery_history_pointer + 1) % per_player.delivery_history_size 
				global.per_player[idx].screensaver_state = following_train
				global.per_player[idx].previous_train = per_player.followed_train
				global.per_player[idx].followed_train = event.train
				global.per_player[idx].train_left_the_depot = false
				global.per_player[idx].train_follow_start_tick = game.tick
				if per_player.character == nil then
					global.per_player[idx].character = game.get_player(idx).character
				end
				local target_entity = game.get_player(idx).character
				if global.per_player[idx].previous_train ~= nil then
					target_entity = global.per_player[idx].previous_train.locomotives.front_movers[1]
				end
				local waypoints = 
					{{target = target_entity, transition_time = 0, time_to_wait = 10},
					{target = event.train.locomotives.front_movers[1], transition_time = per_player.transition_time, time_to_wait = 120}}
				local alt_mode = game.get_player(idx).game_view_settings.show_entity_info 
				game.get_player(idx).set_controller{type=defines.controllers.cutscene, waypoints = waypoints, final_transition_time = 10000}
				game.get_player(idx).game_view_settings.show_entity_info = alt_mode
			end
		end
	end
end


function toggle_screensaver(event)
	local idx = event.player_index
	if global.per_player == nil then global.per_player = {} end

	if global.per_player[idx] == nil then
		global.per_player[idx] = {}
	end

	if global.per_player[idx].screensaver_state == nil or global.per_player[idx].screensaver_state == disabled then
		game.get_player(idx).print("Turning on screensaver. Press CTRL+S to disable.")
		global.per_player[idx].delivery_history = {}
		global.per_player[idx].delivery_history_size = game.players[idx].mod_settings["ltn-scr-delivery-history-size"].value
		global.per_player[idx].delivery_history_pointer = 0
		global.per_player[idx].transition_time = game.players[idx].mod_settings["ltn-scr-transition-time"].value
		global.per_player[idx].screensaver_state = looking_for_train
		global.per_player[idx].followed_train = nil
		global.per_player[idx].game_view_settings = game.get_player(idx).game_view_settings
		script.on_event({defines.events.on_train_schedule_changed}, OnDispatcherUpdated)
		script.on_event({defines.events.on_cutscene_waypoint_reached}, OnWaypointReached)

		game.print(global.per_player[idx].delivery_history_size)
		game.print(global.per_player[idx].transition_time)
	else
		game.get_player(idx).print("Turning off screensaver.")
		global.per_player[idx].screensaver_state = disabled

		if game.get_player(idx).controller_type ~= defines.controllers.character then
			game.get_player(idx).set_controller{type=defines.controllers.character, character=global.per_player[idx].character}
			global.per_player[idx].character = nil
		end
		if global.per_player[idx].game_view_settings ~= nil then
			game.get_player(idx).game_view_settings = global.per_player[idx].game_view_settings
		end

		local disable_event_subscription = true
		for index, per_player in ipairs(global.per_player) do
    		if per_player.screensaver_state ~= nil or per_player.screensaver_state ~= disabled then
            	disable_schedule_update_subscription = false
            	break
        	end
        end
        if disable_event_subscription == true then
        	script.on_event({defines.events.on_train_schedule_changed}, nil)
        	script.on_event({defines.events.on_cutscene_waypoint_reached}, nil)
        	script.on_event({defines.events.on_tick}, nil)
        end
	end
end

script.on_event("pressed-screensaver-key", toggle_screensaver)