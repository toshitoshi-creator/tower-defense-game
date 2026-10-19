class_name PixelArt
extends RefCounted
## Procedural pixel-art placeholders, shared by in-battle units and UI icons.
## Replace with real SpriteFrames via UnitData.sprite_frames when art is ready.

## 12-wide pixel maps. Keys: o outline, h helmet/armor, s skin, g goblin skin, e eye,
## r red eye, k wood, w steel, b body (UnitData.body_color), a accent (UnitData.accent_color).
const PATTERNS := {
	&"soldier": [
		"....oooo....",
		"...ohhhho...",
		"..ohhhhhho..",
		"..osssssso..",
		"..osesseso..",
		"...osssso...",
		"..oobbbboo.w",
		".obbbaabbbow",
		".osbbaabbsow",
		".oobbbbbboow",
		"...oaaaao.w.",
		"...obbbbo...",
		"...obo.obo..",
		"...ooo.ooo..",
	],
	&"archer": [
		"....oooo....",
		"...obbbbo.k.",
		"..obbbbbbo.k",
		"..obssssbo.k",
		"..obessebo.k",
		"...osssso.k.",
		"..obbbbbbok.",
		".obbaabbbbsk",
		".osbaabbbo.k",
		"..obbbbbbo.k",
		"...oaaaao.k.",
		"...obbbbok..",
		"...obo.obo..",
		"...ooo.ooo..",
	],
	&"shield": [
		"...oooooo...",
		"..ohhhhhho..",
		"..ohhhhhho..",
		"..ohssssho..",
		"..ohesseho..",
		"ooooohhhhoo.",
		"oaaaobbbbbo.",
		"oawaobbbbbbo",
		"oawaobbbbbbo",
		"oaaaobbbbbo.",
		".oaaohhhho..",
		"..ooobbbbo..",
		"....obo.obo.",
		"....ooo.ooo.",
	],
	&"goblin": [
		"...oooooo...",
		"o.oggggggo.o",
		"ogoggggggogo",
		".ooggggggoo.",
		"..ogrggrgo..",
		"...oggggo...",
		"..obbbbbbo..",
		".obbabbabbo.",
		"ogobbbbbbogo",
		"..oaaaaaao..",
		"..obbbbbbo..",
		"..ogo..ogo..",
		"..ooo..ooo..",
	],
	&"brute": [
		"...oooooo...",
		"..ohhhhhho..",
		"..ogrggrgo..",
		"..oggwwggo..",
		".oohhhhhhoo.",
		"ohhhhhhhhhho",
		"ogohhaahhogo",
		"ogohhhhhhogo",
		"...oaaaao...",
		"..obbo.obbo.",
		"..oooo.oooo.",
	],
	&"ogre": [
		"..w......w..",
		"..woooooow..",
		"..obbbbbbo..",
		".obbrbbrbbo.",
		".obbbbbbbbo.",
		".obbwbbwbbo.",
		"..obbbbbbo..",
		"oobbbbbbbboo",
		"obbbbbbbbbbo",
		"obobaaaabobo",
		"oo.oaaaao.oo",
		"...obbbbo...",
		"..obbo.obbo.",
		"..oooo.oooo.",
	],
	&"demon_king": [
		"..a.a..a.a..",
		"..aaaaaaaa..",
		"..oaaaaaao..",
		"..obbbbbbo..",
		"..obrbbrbo..",
		"o..obbbbo..o",
		"oo.obbbbo.oo",
		"obooaaaaoobo",
		"obbbbbbbbbbo",
		"obobbaabbobo",
		".o.obbbbo.o.",
		"...obbbbo...",
		"..obbo.obbo.",
		"..oooo.oooo.",
	],
}
const FIXED_COLORS := {
	"o": Color(0.08, 0.07, 0.1),
	"h": Color(0.62, 0.66, 0.72),
	"s": Color(0.96, 0.78, 0.6),
	"g": Color(0.45, 0.72, 0.3),
	"e": Color(0.1, 0.1, 0.15),
	"r": Color(1.0, 0.25, 0.2),
	"k": Color(0.55, 0.36, 0.18),
	"w": Color(0.86, 0.9, 0.95),
}


static func get_rows(pattern: StringName) -> Array:
	return PATTERNS.get(pattern, PATTERNS[&"soldier"])


static func get_size(pattern: StringName, pixel_scale: int) -> Vector2:
	var rows := get_rows(pattern)
	return Vector2((rows[0] as String).length(), rows.size()) * pixel_scale


static func make_palette(data: UnitData) -> Dictionary:
	var palette := FIXED_COLORS.duplicate()
	palette["b"] = data.body_color
	palette["a"] = data.accent_color
	return palette


## Draws the unit's pattern centered on `center` into any CanvasItem's _draw().
static func draw_unit(canvas: CanvasItem, data: UnitData, center: Vector2, pixel_scale: int) -> void:
	var rows := get_rows(data.placeholder_pattern)
	var palette := make_palette(data)
	var origin := (center - get_size(data.placeholder_pattern, pixel_scale) * 0.5).floor()
	var px := Vector2(pixel_scale, pixel_scale)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row[x]
			if palette.has(key):
				canvas.draw_rect(Rect2(origin + Vector2(x, y) * pixel_scale, px), palette[key])
