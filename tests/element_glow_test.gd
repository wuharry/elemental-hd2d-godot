extends SceneTree
## Real renderer regression: with scene lights disabled, every element must feed HDR glow.
## godot --path . --script res://tests/element_glow_test.gd (not --headless)

const FX := preload("res://src/world/element_altar_fx.gd")
var _passed := 0
var _failed := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", label)


func _frame(viewport: SubViewport) -> Image:
	await process_frame
	RenderingServer.force_sync()
	RenderingServer.force_draw(false)
	return viewport.get_texture().get_image()


func _halo_pixels(on: Image, off: Image) -> int:
	var count := 0
	for y in on.get_height():
		for x in on.get_width():
			var a := on.get_pixel(x, y)
			var b := off.get_pixel(x, y)
			# Only count light spilling onto black background, not brighter geometry.
			if maxf(b.r, maxf(b.g, b.b)) < 0.01 and maxf(a.r, maxf(a.g, a.b)) > 0.035:
				count += 1
	return count


func _measure(viewport: SubViewport, env: Environment) -> int:
	env.glow_enabled = false
	await _frame(viewport)
	var off := await _frame(viewport)
	env.glow_enabled = true
	await _frame(viewport)
	var on := await _frame(viewport)
	return _halo_pixels(on, off)


func _ice_faces(viewport: SubViewport, env: Environment, camera: Camera3D) -> void:
	env.glow_enabled = false
	camera.position = Vector3(2, 0.25, 1.5)
	camera.look_at(Vector3.ZERO)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.26, 0.82, 0.26)
	var crystal := MeshInstance3D.new()
	crystal.mesh = prism
	var material := Mats.altar_ice(prism.size)
	crystal.material_override = material
	viewport.add_child(crystal)
	await _frame(viewport)
	var image := await _frame(viewport)
	var middle := Vector2i(camera.unproject_position(Vector3(0.065, 0, 0)))
	var edge := Vector2i(camera.unproject_position(Vector3(0.065, 0, 0.12)))
	var body_color := image.get_pixelv(middle)
	var edge_color := image.get_pixelv(edge)
	_check(body_color.b > body_color.g and body_color.g < 0.7, "ice sloping-face interior remains blue without scene lights or bloom")
	_check(edge_color.g > body_color.g + 0.15, "ice extrusion border is brighter than its face interior")
	# Recreate the former triangle-only mask on the same mesh, pose and camera.
	var regression := Shader.new()
	regression.code = material.shader.code.replace(
		"float edge = 1.0 - step(0.03125, border_distance);",
		"float edge = 1.0 - step(0.03125, profile_distance);")
	var wrong_material := material.duplicate() as ShaderMaterial
	wrong_material.shader = regression
	crystal.material_override = wrong_material
	await _frame(viewport)
	var wrong := await _frame(viewport)
	_check(wrong.get_pixelv(middle).g >= 0.7, "face-interior check detects the old overbright prism mask")
	crystal.free()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("NOT RUN: element glow checks need a rendered backend; remove --headless")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.glow_enabled = true
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	viewport.add_child(world_env)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.8
	camera.position = Vector3(0, 0.62, 3)
	viewport.add_child(camera)
	camera.make_current()
	# Prove the image gate can distinguish real HDR output from ignored EMISSION.
	var control := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	control.mesh = quad
	control.position.y = 0.62
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; uniform float brightness = 1.0; void fragment() { ALBEDO = vec3(0.7, 0.1, 0.2) * brightness; EMISSION = vec3(40.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	control.material_override = material
	viewport.add_child(control)
	_check(await _measure(viewport, env) == 0, "gate rejects EMISSION written into an unshaded shader")
	material.set_shader_parameter("brightness", 8.0)
	_check(await _measure(viewport, env) >= 12, "gate accepts actual HDR output from the same shader")
	control.free()
	for element: int in Elements.SELECTABLE:
		var fx := FX.new(element)
		viewport.add_child(fx)
		fx.set_process(false)
		fx.advance(0.47)
		for child in fx.get_children():
			if child is Light3D:
				child.visible = false
		var spill := await _measure(viewport, env)
		_check(spill >= 12, "%s has a visible self-lit halo without scene lights (%d pixels)" % [Elements.display_name(element), spill])
		print("glow ", Elements.display_name(element), ": ", spill, " halo pixels")
		fx.free()
	await _ice_faces(viewport, env, camera)
	viewport.free()
	Mats.reset()
	print("element glow: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)
