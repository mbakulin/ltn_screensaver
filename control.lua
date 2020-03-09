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

function FollowOnTick(event)
	local ticks_elapsed = event.tick - global.train_follow_start_tick
	local locomotive_position = global.followed_train.locomotives.front_movers[1].position
	local target_position = locomotive_position
	if ticks_elapsed < global.transition_time then
		local ticks_left = global.transition_time - ticks_elapsed
		local player_position = game.get_player(1).position
		target_position.x = player_position.x + (locomotive_position.x - player_position.x)/ticks_left
		target_position.y = player_position.y + (locomotive_position.y - player_position.y)/ticks_left
	end
	game.get_player(1).teleport(target_position)
	if event.tick % 120 == 0 then
		if global.followed_train.schedule.current ~= 1 then
			global.train_left_the_depot = true
		elseif global.train_left_the_depot == true then
			global.screensaver_state = looking_for_train
			script.on_event({defines.events.on_train_schedule_changed}, OnDispatcherUpdated)
		end
	end
end

function OnDispatcherUpdated(event)
	if global.screensaver_state == looking_for_train and table_size(event.train.schedule.records) ~= 1 then
		local item = nil
		for index, wait_condition in pairs(event.train.schedule.records[2].wait_conditions) do
			if wait_condition.condition ~= nil then
				item = 	wait_condition.condition.first_signal.name
				break
			end
		end
		if has_value(global.delivery_history, item) == true then
			return
		end
		global.delivery_history[global.delivery_history_pointer] = item
		global.delivery_history_pointer = (global.delivery_history_pointer + 1) % global.delivery_history_size 
		script.on_event({defines.events.on_train_schedule_changed}, nil)
		global.screensaver_state = following_train
		global.followed_train = event.train
		global.train_left_the_depot = false
		global.train_follow_start_tick = game.tick
		script.on_event({defines.events.on_tick}, FollowOnTick)
		if global.character == nil then
			global.character = game.get_player(1).character
		end
		game.get_player(1).set_controller{type=defines.controllers.ghost}
	end
end


function toggle_screensaver(event)
	if global.screensaver_state == disabled then
		game.print("Turning on screensaver. Press CTRL+S to disable.")
		global.delivery_history = {}
		global.delivery_history_size = 10
		global.delivery_history_pointer = 0
		global.transition_time = 300
		global.screensaver_state = looking_for_train
		script.on_event({defines.events.on_train_schedule_changed}, OnDispatcherUpdated)
	else
		game.print("Turning off screensaver.")
		script.on_event({defines.events.on_train_schedule_changed}, nil)
		script.on_event({defines.events.on_tick}, nil)
		if game.get_player(1).controller_type ~= defines.controllers.character then
			game.get_player(1).set_controller{type=defines.controllers.character, character=global.character}
			global.character = nil
		end
		global.screensaver_state = disabled
	end
end

script.on_event("pressed-screensaver-key", toggle_screensaver)