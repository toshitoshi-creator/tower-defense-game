class_name UnitData
extends Resource
## Data definition shared by allies and enemies.
## Adding a new unit type = adding a new .tres file; combat logic lives in Combatant.

enum AttackType { MELEE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Stats")
@export var max_hp: int = 100
@export var attack: int = 10
@export var defense: int = 0
## Seconds between attacks.
@export var attack_interval: float = 1.0
## Pixels per second.
@export var move_speed: float = 40.0
## Edge-to-edge reach of an attack, in pixels.
@export var attack_range: float = 6.0
## Distance at which the unit notices and walks toward an opponent.
@export var aggro_range: float = 110.0
@export var attack_type: AttackType = AttackType.MELEE

@export_group("Economy")
@export var summon_cost: int = 0
@export var reward: int = 0

@export_group("Visual")
## Optional real sprite. Expected animations: idle, move, attack, hurt, death.
## When null, a procedural pixel-art placeholder is drawn instead.
@export var sprite_frames: SpriteFrames
@export var placeholder_pattern: StringName = &"soldier"
@export var body_color: Color = Color(0.25, 0.45, 0.85)
@export var accent_color: Color = Color(0.9, 0.8, 0.3)
@export var pixel_scale: int = 2
## Collision-ish radius used for range checks and spacing.
@export var body_radius: float = 10.0

@export_group("Special")
@export var abilities: Array[StringName] = []
@export var is_boss: bool = false
