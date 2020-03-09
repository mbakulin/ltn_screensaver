disabled = "disbled"
looking_for_train = "looking_for_train"
following_train = "following_train"

function FollowOnTick(event) 
	game.get_player(1).teleport(global.followed_train.locomotives.front_movers[1].position)
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
		script.on_event({defines.events.on_train_schedule_changed}, nil)
		global.screensaver_state = following_train
		global.followed_train = event.train
		global.train_left_the_depot = false
		--game.print(table.tostring(global.followed_train.schedule))
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
		script.on_event({defines.events.on_train_schedule_changed}, OnDispatcherUpdated)
		global.screensaver_state = looking_for_train
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

global.screensaver_state = disabled
script.on_event("pressed-screensaver-key", toggle_screensaver)