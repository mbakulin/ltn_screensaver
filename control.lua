disabled = "disbled"
looking_for_train = "looking_for_train"
following_train = "following_train"
transition = "transition"
controller_transition_time = 15

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
	for idx, per_player in ipairs(global.per_player) do
		if per_player.followed_train ~= nil and per_player.screensaver_state ~= transition then
			if event.tick % 120 == 0 then
				if per_player.followed_train.schedule.current ~= 1 then
					global.per_player[idx].train_left_the_depot = true
				elseif per_player.train_left_the_depot == true then
					global.per_player[idx].screensaver_state = looking_for_train
				end
			end
			if event.tick - per_player.cutscene_waypoint_reached_tick > controller_transition_time then
				game.get_player(idx).teleport(global.per_player[idx].followed_train.locomotives.front_movers[1].position)
			else
				--need some gradual transition between cutscene controller and ghost controller
				--first controller_transition_time ticks teleport position is calculated as train_position+speed_per_tick*magic_coeff
				--magic_coeff if gradually changing from 1 to 0 during transition time
				local orientation = global.per_player[idx].followed_train.locomotives.front_movers[1].orientation
				local angle = -orientation * math.pi * 2 + math.pi / 2
				local dx = math.cos(angle) * global.per_player[idx].followed_train.locomotives.front_movers[1].speed
				local dy = math.sin(angle) * global.per_player[idx].followed_train.locomotives.front_movers[1].speed
				local target_position = global.per_player[idx].followed_train.locomotives.front_movers[1].position
				local elapsed_transition_time = event.tick - per_player.cutscene_waypoint_reached_tick - 1
				local magic_coeff = (controller_transition_time - elapsed_transition_time) / controller_transition_time
				target_position.x = target_position.x + dx*magic_coeff
				target_position.y = target_position.y - dy*magic_coeff
				game.get_player(idx).teleport(target_position)
			end
		end
	end
end

function OnWaypointReached(event)
	local idx = event.player_index
	local per_player = global.per_player[idx]
	if per_player.followed_train ~= nil then
		if game.tick - per_player.train_follow_start_tick >= per_player.transition_time then
			global.per_player[idx].screensaver_state = following_train
			global.per_player[idx].cutscene_waypoint_reached_tick = event.tick
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
			game.get_player(idx).teleport(global.per_player[idx].followed_train.locomotives.front_movers[1].position)
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
				global.per_player[idx].followed_train = event.train
				global.per_player[idx].train_left_the_depot = false
				global.per_player[idx].train_follow_start_tick = game.tick
				if per_player.character == nil then
					global.per_player[idx].character = game.get_player(idx).character
				end
				local last_position = game.get_player(idx).position
				local waypoints = 
					{{position = last_position, transition_time = 0, time_to_wait = 0},
					{target = event.train.locomotives.front_movers[1], transition_time = per_player.transition_time, time_to_wait = 1}}
				local alt_mode = game.get_player(idx).game_view_settings.show_entity_info 
				global.per_player[idx].screensaver_state = transition
				game.get_player(idx).set_controller{type=defines.controllers.cutscene, waypoints = waypoints, final_transition_time = 10000}
				game.get_player(idx).game_view_settings.show_entity_info = alt_mode
			end
		end
	end
end


function toggle_screensaver(event)
	script.on_event(defines.events.on_runtime_mod_setting_changed, mod_settings_changed)
	local idx = event.player_index
	if global.per_player == nil then global.per_player = {} end

	if global.per_player[idx] == nil then
		global.per_player[idx] = {}
	end

	if game.get_player(idx).controller_type == defines.controllers.editor then
		game.get_player(idx).print("Can't be used with editor controller.")
		return
	end

	if global.per_player[idx].screensaver_state == nil or global.per_player[idx].screensaver_state == disabled then
		game.get_player(idx).print("Turning on screensaver. Press CTRL+S to disable.")
		global.per_player[idx].delivery_history_size = game.players[idx].mod_settings["ltn-scr-delivery-history-size"].value
		if game.players[idx].mod_settings["ltn-scr-reset-history"].value == true or global.per_player[idx].delivery_history == nil then
			global.per_player[idx].delivery_history = {}
			for i=0,global.per_player[idx].delivery_history_size-1 do
				global.per_player[idx].delivery_history[i] = nil
			end 
			global.per_player[idx].delivery_history_pointer = 0
		end
		global.per_player[idx].transition_time = game.players[idx].mod_settings["ltn-scr-transition-time"].value
		global.per_player[idx].screensaver_state = looking_for_train
		global.per_player[idx].followed_train = nil
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
		script.on_event({defines.events.on_train_schedule_changed}, OnDispatcherUpdated)
		script.on_event({defines.events.on_cutscene_waypoint_reached}, OnWaypointReached)
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

function mod_settings_changed(event)
	game.print("Mod settings changed")
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
	if event.setting == "ltn-scr-delivery-history-size" then
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
		for i=0,old_delivery_history_size-1 do
			new_delivery_history[new_pointer] = old_delivery_history[old_pointer]
			new_pointer = (new_pointer + 1) % new_delivery_history_size
			old_pointer = (old_pointer + 1) % old_delivery_history_size
			game.print(dump(new_delivery_history))
		end
		global.per_player[idx].delivery_history = new_delivery_history
		global.per_player[idx].delivery_history_size = new_delivery_history_size
		global.per_player[idx].delivery_history_pointer = new_pointer
		return
	end
end

script.on_event("pressed-screensaver-key", toggle_screensaver)