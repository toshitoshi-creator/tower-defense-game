extends SceneTree
## Dev tool: run the battle for N seconds (sped up) and save a screenshot.
## Usage: godot --path . -s res://tools/capture_screenshot.gd -- <seconds> <out.png> [time_scale] [bot]
## With "bot", every ready and affordable summon slot is tapped twice a second.
## Requires a real rendering driver (not --headless), e.g. under xvfb-run.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 10.0
	var out_path := args[1] if args.size() > 1 else "user://screenshot.png"
	var use_bot := args.size() > 3 and args[3] == "bot"
	var battle := load("res://scenes/battle/battle.tscn").instantiate() as BattleManager
	root.add_child(battle)
	current_scene = battle
	await process_frame
	Engine.time_scale = float(args[2]) if args.size() > 2 else 1.0
	var timer := create_timer(seconds, true, false, false)
	while timer.time_left > 0.0:
		if use_bot and battle.is_running():
			for slot in [2, 0, 1]:
				if battle.summoner.check_summon(slot) == SummonManager.Reason.OK:
					battle.request_summon(slot)
		await create_timer(0.5, true, false, false).timeout
	Engine.time_scale = 1.0
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out_path)
	print("saved ", out_path, " ", image.get_size())
	quit()
