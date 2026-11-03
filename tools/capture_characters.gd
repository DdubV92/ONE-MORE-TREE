extends Node
## Renders the character preview to captures/ (idle, walk mid-stride, swing
## impact, dog lie) for documentation and review.

func _ready() -> void:
	var scene: Node3D = load("res://scenes/character_preview.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var shots := [["idle", "idle", 0.5], ["walk", "walk", 0.27], ["swing", "lie", 0.76]]
	for s in shots:
		scene.human.play(s[0], 0.0)
		scene.dog.play(s[1], 0.0)
		scene.human.anim.seek(s[2], true)
		scene.dog.anim.seek(0.1, true)
		scene.human._process(0.0)
		for i in 10:
			await get_tree().process_frame
		scene.human.anim.seek(s[2], true)
		scene.dog.anim.seek(0.1, true)
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://captures/characters_%s.png" % s[0])
		print("captured characters_", s[0])
	get_tree().quit()
