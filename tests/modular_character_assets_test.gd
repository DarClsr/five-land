extends SceneTree

const ASSET_ROOT := "res://assets/characters/wuyang/modular/"
const ASSETS := [
	"outfit_wanderer_8dir_atlas.png",
	"outfit_earth_guard_8dir_atlas.png",
	"weapon_none_8dir_atlas.png",
	"weapon_dual_daggers_8dir_atlas.png",
]

var failures: int = 0


func _init() -> void:
	var manifest_text := FileAccess.get_file_as_string(ASSET_ROOT + "wuyang_modular_manifest.json")
	var manifest := JSON.parse_string(manifest_text) as Dictionary
	_expect(not manifest.is_empty(), "loads the modular character manifest")
	var cell_size := manifest.get("cell_size") as Array
	_expect(
		cell_size.size() == 2 and int(cell_size[0]) == 128 and int(cell_size[1]) == 128,
		"uses native 128px cells"
	)
	_expect((manifest.get("outfits") as Array).size() == 2, "provides two switchable outfits")
	_expect((manifest.get("weapons") as Array).size() == 2, "provides two weapon states")
	for filename: String in ASSETS:
		var texture := load(ASSET_ROOT + filename) as Texture2D
		_expect(texture != null, "loads %s" % filename)
		if texture != null:
			_expect(texture.get_size() == Vector2(1024, 1024), "%s follows the atlas contract" % filename)
	if failures == 0:
		print("PASS: modular character assets")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)
