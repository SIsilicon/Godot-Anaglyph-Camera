@tool 
@icon("anaglyph_camera.svg")
extends Camera3D
class_name AnaglyphCamera
   
# How far apart the "eyes" are. A larger value makes a stronger anaglyph effect.
var separation = 0.1 #setget set_separation

# The distance at which rendered object appear normal. 
var convergence = 100.0 #setget set_convergence

# How black and white the image should be.
var greyscale = 0.0 #setget set_greyscale

# Whether the scene should be rendered at half vertical resolution.
var half_res = 0.0 #setget set_half_res

var _anaglyph: Node3D
var _viewport: Viewport 

func _get_property_list() -> Array:
	var properties := [
		{name="AnaglyphCamera", type=TYPE_NIL, usage=PROPERTY_USAGE_CATEGORY}, 
		{name="separation", type=TYPE_FLOAT, hint=PROPERTY_HINT_RANGE, hint_string="-8, 8, 0.01, or_greater, or_lesser"},
		{name="convergence", type=TYPE_FLOAT, hint=PROPERTY_HINT_EXP_EASING|PROPERTY_HINT_RANGE, hint_string="0.01, 2048, 0.01, or_greater"},
		{name="greyscale", type=TYPE_FLOAT, hint=PROPERTY_HINT_RANGE, hint_string="0.0, 1.0, 0.01"},
		{name="half_res", type=TYPE_FLOAT, hint=PROPERTY_HINT_RANGE, hint_string="0.0, 1.0, 0.01"},
	]
	return properties
 

func _enter_tree() -> void:
	_anaglyph = preload("anaglyph_setup.tscn").instantiate()

	var material_inst: ShaderMaterial = \
			_anaglyph_node("Composite").material.duplicate()
	_anaglyph_node("Composite").material = material_inst
	add_child(_anaglyph)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		for camera in [_anaglyph_node("Left/Camera"), _anaglyph_node("Right/Camera")]:
			_update_camera_properties(camera)
		_anaglyph_node("Composite").visible = false


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return


	if what == NOTIFICATION_ENTER_WORLD:
		set_process_internal(true)
		_viewport = get_viewport()
	elif what == NOTIFICATION_EXIT_WORLD:
		RenderingServer.viewport_set_disable_3d(_viewport.get_viewport_rid(), _viewport.disable_3d)
		_viewport = null
	elif what == NOTIFICATION_INTERNAL_PROCESS:
		if not _viewport:
			return

		var is_current_cam : bool = _viewport.get_camera_3d() == self

		_anaglyph_node("Composite").visible = is_current_cam
		RenderingServer.viewport_set_disable_3d(_viewport.get_viewport_rid(), is_current_cam)
		_update_camera_viewport_properties(_anaglyph_node("Left"), is_current_cam)
		_update_camera_viewport_properties(_anaglyph_node("Right"), is_current_cam)


func set_separation(value: float) -> void:
	separation = value


func set_convergence(value: float) -> void:
	convergence = max(value, 0.01)


func set_greyscale(value: float) -> void:
	if not _anaglyph:
		return
	
	greyscale = clamp(value, 0.0, 1.0)
	_anaglyph_node("Composite").material.set_shader_param(
		"black_and_white", greyscale
	)


func set_half_res(value: float) -> void:
	if not _anaglyph:
		return
	
	half_res = clamp(value, 0.0, 1.0)
	_anaglyph_node("Composite").material.set_shader_param(
		"half_res", half_res
	)


func _update_camera_viewport_properties(view: Viewport, _is_current: bool) -> void:
	if not _anaglyph:
		return

	view.size = _viewport.size # * Vector2.ONE.lerp(Vector2(1.0, 0.5), half_res);
	if half_res:
		view.size = view.size / 2
	view.msaa_3d = _viewport.msaa_3d
	# view.hdr = _viewport.hdr
	view.disable_3d = _viewport.disable_3d
	# keep_3d_linear = _viewport.keep_3d_linear
	# view.usage = _viewport.usage
	view.debug_draw = _viewport.debug_draw
	view.transparent_bg = _viewport.transparent_bg 
	# view.render_target_v_flip = _viewport.render_target_v_flip
	# view.render_target_clear_mode = _viewport.render_target_clear_mode
	# view.render_target_update_mode = _viewport.render_target_update_mode if is_current else Viewport.UPDATE_DISABLED
	# if view.render_target_update_mode == Viewport.UPDATE_WHEN_VISIBLE and OS.get_current_video_driver() == OS.VIDEO_DRIVER_GLES3:
	view.render_target_update_mode = SubViewport.UpdateMode.UPDATE_ALWAYS
	view.positional_shadow_atlas_size = _viewport.positional_shadow_atlas_size
	view.positional_shadow_atlas_quad_0 = _viewport.positional_shadow_atlas_quad_0
	view.positional_shadow_atlas_quad_1 = _viewport.positional_shadow_atlas_quad_1
	view.positional_shadow_atlas_quad_2 = _viewport.positional_shadow_atlas_quad_2
	view.positional_shadow_atlas_quad_3 = _viewport.positional_shadow_atlas_quad_3
	view.positional_shadow_atlas_16_bits = _viewport.positional_shadow_atlas_16_bits
	
	_update_camera_properties(view.get_camera_3d())


func _update_camera_properties(camera: Camera3D) -> void:
	if not _anaglyph:
		return

	var side := 1.0 if camera == _anaglyph_node("Right/Camera") else -1.0
	
	camera.far = far
	camera.near = near
	var cam_size: float = tan(deg_to_rad(fov) * 0.5) * near * 2.0
	# The near plane will have to enlargen to comenspate for the small camera size
	if cam_size < 0.1:
		camera.near = camera.near / cam_size * 0.1
		cam_size = 0.1
	camera.size = cam_size
	camera.frustum_offset = Vector2(separation / (camera.size / camera.near * convergence) * camera.near, 0) * -side
	camera.h_offset = h_offset
	camera.v_offset = v_offset
	camera.environment = environment
	camera.cull_mask = cull_mask
	
	camera.transform = global_transform
	camera.translate_object_local(Vector3.RIGHT * separation * side)


func _anaglyph_node(path: NodePath) -> Node:
	if not _anaglyph:
		return null

	return _anaglyph.get_node(path)
