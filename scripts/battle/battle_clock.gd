class_name BattleClock
extends Node
## Monotonic battle timer. Only advances while running; stop() freezes it for good
## until reset(). Pausing the SceneTree also pauses it (default process mode).

signal second_elapsed(total_seconds: int)

var elapsed: float = 0.0
var running: bool = false

var _last_whole_second: int = 0


func start() -> void:
	running = true


func stop() -> void:
	running = false


func reset() -> void:
	elapsed = 0.0
	_last_whole_second = 0
	running = false


func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	var whole := int(elapsed)
	if whole != _last_whole_second:
		_last_whole_second = whole
		second_elapsed.emit(whole)


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]
