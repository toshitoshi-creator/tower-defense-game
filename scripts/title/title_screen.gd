extends Control
## Title screen: one big start button plus a short how-to. No network, no saves.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const LINEUP := [
	"res://resources/units/soldier.tres",
	"res://resources/units/archer.tres",
	"res://resources/units/shield.tres",
	"res://resources/enemies/grunt.tres",
	"res://resources/enemies/ogre.tres",
	"res://resources/enemies/demon_king.tres",
]

@onready var backdrop: BattlefieldBackground = $Backdrop
@onready var margin: MarginContainer = $Margin
@onready var lineup: HBoxContainer = $Margin/Column/Lineup
@onready var start_button: Button = $Margin/Column/StartButton


func _ready() -> void:
	get_tree().paused = false
	for path in LINEUP:
		var icon := UnitIcon.new()
		icon.pixel_scale = 3
		lineup.add_child(icon)
		icon.set_unit(load(path) as UnitData)
	start_button.pressed.connect(start_battle)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	var pulse := create_tween().set_loops()
	pulse.tween_property(start_button, "modulate", Color(1.15, 1.15, 1.15), 0.6)
	pulse.tween_property(start_button, "modulate", Color.WHITE, 0.6)


func start_battle() -> void:
	# Deferred: this runs from a button press, which must finish before its scene goes.
	get_tree().change_scene_to_file.call_deferred(BATTLE_SCENE)


func _relayout() -> void:
	var view := get_viewport_rect().size
	backdrop.set_area(Rect2(Vector2.ZERO, view), 0.0, view.y)
	var m := SafeArea.get_margins(get_viewport())
	margin.add_theme_constant_override("margin_left", int(m.left) + 16)
	margin.add_theme_constant_override("margin_right", int(m.right) + 16)
	margin.add_theme_constant_override("margin_top", int(m.top) + 24)
	margin.add_theme_constant_override("margin_bottom", int(m.bottom) + 24)
