extends Node3D
## Phase 24: bakes a worker's sprites and captures the 3D body vs the HD-2D
## sprite from several angles and clips (lavapipe-friendly).
## Usage: godot --rendering-driver vulkan res://tools/art/pixel_actor_test.tscn
## Output: captures/p24_pixel_actor_<clip>_<angle>.png and a contact sheet.

var ch: HumanCharacter
var pa: PixelActor
var cam: Camera3D


func _ready() -> void:
	Settings.values.character_style = "hd2d"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.68, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.3, 0.2)
	ground.material_override = gm
	add_child(ground)
	ch = HumanCharacter.new()
	ch.appearance = HumanAppearance.for_employee(OS.get_environment("EMP") if OS.has_environment("EMP") else "EMP-02", 1)
	add_child(ch)
	pa = PixelActor.attach(ch)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var shots: Array = []
	for clip in ["idle", "walk", "swing"]:
		ch.play(clip, 0.0)
		# Wait for the bake of this clip.
		var g := 0
		while g < 600 and not pa._clips.has(clip):
			await get_tree().process_frame
			g += 1
		await get_tree().create_timer(0.35).timeout
		for ang in [0, 45, 90, 135, 180, 270]:
			var a := deg_to_rad(float(ang))
			cam.global_position = Vector3(sin(a) * 4.2, 1.5, cos(a) * 4.2)
			cam.look_at(Vector3(0, 1.0, 0))
			for mode in ["3d", "hd2d"]:
				Settings.values.character_style = "clean" if mode == "3d" else "hd2d"
				for f in 3:
					await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				var path := "res://captures/p24_pixel_actor_%s_%03d_%s.png" % [clip, ang, mode]
				img.save_png(path)
				shots.append(path)
	print("PIXEL_ACTOR baked=%d shown_frames=%d shots=%d" % [PixelBaker.instance().baked_clips, pa.shown_frames, shots.size()])
	get_tree().quit()
