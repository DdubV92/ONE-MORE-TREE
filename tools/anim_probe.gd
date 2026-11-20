extends Node3D
## Animation metrics (headless): samples every clip of the human rig and
## prints where the key joints are, so a pose can be checked in numbers.
##   godot --headless res://tools/anim_probe.tscn -- [clip ...]

func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	var h := HumanCharacter.new()
	h.appearance = HumanAppearance.for_employee("EMP-01", 1)
	add_child(h)
	await get_tree().process_frame
	var only: Array = Array(OS.get_cmdline_user_args())
	var names: Array = Array(h.anim.get_animation_list())
	names.sort()
	for n in names:
		if not only.is_empty() and not str(n) in only:
			continue
		var an: Animation = h.anim.get_animation(str(n))
		print("CLIP %s len %.2f" % [n, an.length])
		for i in 9:
			var t := minf(an.length * i / 8.0, an.length - 0.001)
			h.current = ""
			h.action = ""
			h.play(str(n), 0.0)
			h.anim.seek(t, true)
			h._process(0.0)
			var out := "  t %.2f" % t
			for b in ["Hips", "Head", "HandL", "HandR", "FootL", "FootR"]:
				var p: Vector3 = h.to_local((h.bones[b] as Node3D).global_position)
				out += "  %s(%.2f %.2f %.2f)" % [b, p.x, p.y, p.z]
			print(out)
	get_tree().quit()
