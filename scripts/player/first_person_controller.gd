class_name FirstPersonController
extends CharacterBody3D

signal stamina_changed(current_stamina: float, maximum_stamina: float)

const FOOTSTEP_STREAMS: Array[AudioStream] = [
	preload("res://sounds/footsteps/data_pion-st1-footstep-sfx-323053.mp3"),
	preload("res://sounds/footsteps/data_pion-st2-footstep-sfx-323055.mp3"),
	preload("res://sounds/footsteps/data_pion-st3-footstep-sfx-323056.mp3"),
]

@export_group("Movement")
@export var walk_speed: float = 2.5
@export var sprint_speed: float = 5.0
@export var crouch_speed: float = 1.25
@export var ground_acceleration: float = 10.0
@export var air_acceleration: float = 3.0
@export var jump_velocity: float = 6.0
@export_range(0.8, 2.0, 0.05) var crouch_height: float = 1.1
@export_range(0.1, 10.0, 0.1) var crouch_transition_speed: float = 4.0

@export_group("Sprint Stamina")
@export_range(0.1, 30.0, 0.1) var sprint_duration: float = 4.0
@export_range(0.0, 10.0, 0.1) var stamina_regeneration_delay: float = 2.5
@export_range(0.1, 30.0, 0.1) var stamina_regeneration_duration: float = 5.0
@export_range(0.0, 1.0, 0.01) var exhaustion_vignette_strength: float = 0.6
@export_range(0.0, 3.0, 0.05) var exhaustion_vignette_fade_in_duration: float = 0.45
@export_range(0.0, 3.0, 0.05) var exhaustion_vignette_fade_out_duration: float = 0.9

@export_group("Footsteps")
@export_range(0.1, 1.0, 0.01) var walk_step_interval: float = 0.44
@export_range(0.1, 1.0, 0.01) var sprint_step_interval: float = 0.34
@export_range(-40.0, 0.0, 0.5) var footstep_volume_db: float = -22.0
@export_range(0.0, 6.0, 0.1) var footstep_volume_variation_db: float = 1.5
@export_range(0.0, 0.25, 0.01) var footstep_pitch_variation: float = 0.05

@export_group("Camera")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.1
@export_range(-89.0, 0.0, 1.0) var minimum_look_angle: float = -89.0
@export_range(0.0, 89.0, 1.0) var maximum_look_angle: float = 89.0
@export_range(0.0, 0.9, 0.01) var zoom_amount: float = 0.6
@export_range(0.1, 10.0, 0.1) var zoom_duration: float = 0.7
@export_range(0.0, 0.1, 0.005) var head_bob_vertical_amount: float = 0.035
@export_range(0.0, 0.1, 0.005) var head_bob_horizontal_amount: float = 0.02
@export_range(0.1, 5.0, 0.1) var head_bob_frequency: float = 2.0
@export_range(1.0, 20.0, 0.5) var head_bob_smoothing: float = 10.0

@export_group("Fog")
@export var fog_enabled: bool = true
@export_enum("Exponential", "Depth") var fog_mode: int = 1
@export var fog_light_color: Color = Color(0.008, 0.01, 0.014, 1.0)
@export_range(0.0, 1.0, 0.001) var fog_density: float = 1.0
@export_range(0.0, 1000.0, 0.1) var fog_depth_begin: float = 10.0
@export_range(0.0, 1000.0, 0.1) var fog_depth_end: float = 22.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var screen_filter: ColorRect = $RetroScreenEffect/ScreenFilter
@onready var screen_effect_material: ShaderMaterial = screen_filter.material
@onready var heartbeat_player: AudioStreamPlayer = $HeartbeatPlayer
@onready var footstep_players: Array[AudioStreamPlayer] = [
	$FootstepPlayerA,
	$FootstepPlayerB,
]

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _pitch: float = 0.0
var _default_camera_fov: float
var _default_camera_position: Vector3
var _standing_head_position: Vector3
var _target_head_position: Vector3
var _standing_collision_position: Vector3
var _standing_body_position: Vector3
var _standing_height: float
var _collision_capsule: CapsuleShape3D
var _body_capsule_mesh: CapsuleMesh
var _standing_clearance_shape: CapsuleShape3D
var _head_bob_phase: float = 0.0
var _zoom_tween: Tween
var _footstep_timer: float = 0.0
var _next_footstep_player: int = 0
var _next_footstep_stream: int = 0
var _footstep_rng := RandomNumberGenerator.new()
var stamina: float = 0.0
var _stamina_regeneration_cooldown: float = 0.0
var _sprint_exhausted: bool = false
var _exhaustion_vignette_tween: Tween
var _is_exhaustion_effect_active := false
var is_crouching: bool = false:
	set(value):
		if is_crouching == value:
			return
		is_crouching = value
		if is_node_ready():
			_apply_stance(value, not is_multiplayer_authority())


func _ready() -> void:
	var is_local_player := is_multiplayer_authority()
	stamina = sprint_duration
	stamina_changed.emit(stamina, sprint_duration)
	_default_camera_fov = camera.fov
	_default_camera_position = camera.position
	_cache_stance_geometry()
	_apply_stance(is_crouching, true)
	set_physics_process(is_local_player)
	set_process_unhandled_input(is_local_player)
	camera.current = is_local_player
	interaction_ray.enabled = is_local_player
	body_mesh.visible = not is_local_player
	screen_filter.visible = is_local_player
	if is_local_player:
		_configure_fog()
		screen_effect_material.set_shader_parameter("exhaustion_vignette_strength", 0.0)
		var heartbeat_stream := heartbeat_player.stream.duplicate() as AudioStreamMP3
		heartbeat_stream.loop = true
		heartbeat_player.stream = heartbeat_stream
		_footstep_rng.randomize()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _configure_fog() -> void:
	if not is_multiplayer_authority():
		return

	var world_environment := get_world_3d().environment
	if world_environment == null:
		return

	var local_environment := world_environment.duplicate() as Environment
	local_environment.fog_enabled = fog_enabled
	local_environment.fog_mode = fog_mode
	local_environment.fog_light_color = fog_light_color
	local_environment.fog_density = fog_density
	local_environment.fog_depth_begin = fog_depth_begin
	local_environment.fog_depth_end = fog_depth_end
	camera.environment = local_environment


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_set_zoomed(false)
	elif event.is_action_pressed("zoom"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_set_zoomed(true)
	elif event.is_action_released("zoom"):
		_set_zoomed(false)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(input_direction.x, 0.0, input_direction.y)
	var movement_direction := (transform.basis * local_direction).normalized()
	_update_crouch_state(Input.is_action_pressed("crouch"))
	var sprint_held := Input.is_action_pressed("sprint")
	if not sprint_held:
		_sprint_exhausted = false
	var is_sprinting := (
		sprint_held
		and not input_direction.is_zero_approx()
		and not is_crouching
		and not _sprint_exhausted
		and stamina > 0.0
	)
	_update_stamina(delta, is_sprinting)
	var target_speed := crouch_speed if is_crouching else (
		sprint_speed if is_sprinting else walk_speed
	)
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, movement_direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, movement_direction.z * target_speed, acceleration * delta)

	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not is_crouching:
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta

	move_and_slide()
	_update_crouch_camera(delta)
	_update_footsteps(delta, not input_direction.is_zero_approx(), is_sprinting)
	_update_camera_bob(delta)


func _cache_stance_geometry() -> void:
	var collision_capsule := collision_shape.shape as CapsuleShape3D
	var body_capsule_mesh := body_mesh.mesh as CapsuleMesh
	assert(collision_capsule != null, "The player collision shape must be a CapsuleShape3D.")
	assert(body_capsule_mesh != null, "The player body mesh must be a CapsuleMesh.")

	_collision_capsule = collision_capsule.duplicate() as CapsuleShape3D
	collision_shape.shape = _collision_capsule
	_body_capsule_mesh = body_capsule_mesh.duplicate() as CapsuleMesh
	body_mesh.mesh = _body_capsule_mesh
	_standing_clearance_shape = _collision_capsule.duplicate() as CapsuleShape3D
	_standing_height = _collision_capsule.height
	_standing_collision_position = collision_shape.position
	_standing_body_position = body_mesh.position
	_standing_head_position = head.position
	_target_head_position = _standing_head_position


func _update_crouch_state(crouch_requested: bool) -> void:
	if crouch_requested:
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false


func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _standing_clearance_shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY, _standing_collision_position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply_stance(crouching: bool, snap_head: bool = false) -> void:
	var target_height := maxf(crouch_height, _collision_capsule.radius * 2.0) if crouching else _standing_height
	var height_difference := _standing_height - target_height
	_collision_capsule.height = target_height
	collision_shape.position = _standing_collision_position - Vector3.UP * height_difference * 0.5
	_body_capsule_mesh.height = target_height
	body_mesh.position = _standing_body_position - Vector3.UP * height_difference * 0.5
	_target_head_position = _standing_head_position - Vector3.UP * height_difference
	if snap_head:
		head.position = _target_head_position


func _update_crouch_camera(delta: float) -> void:
	head.position = head.position.move_toward(_target_head_position, crouch_transition_speed * delta)


func _update_stamina(delta: float, is_sprinting: bool) -> void:
	var previous_stamina := stamina
	if is_sprinting:
		stamina = maxf(stamina - delta, 0.0)
		_stamina_regeneration_cooldown = stamina_regeneration_delay
		if stamina <= 0.0:
			_sprint_exhausted = true
	else:
		var regeneration_delta := delta
		if _stamina_regeneration_cooldown > 0.0:
			regeneration_delta = maxf(delta - _stamina_regeneration_cooldown, 0.0)
			_stamina_regeneration_cooldown = maxf(
				_stamina_regeneration_cooldown - delta,
				0.0
			)

		if regeneration_delta > 0.0 and stamina < sprint_duration:
			var regeneration_rate := sprint_duration / stamina_regeneration_duration
			stamina = minf(stamina + regeneration_rate * regeneration_delta, sprint_duration)
			if is_equal_approx(stamina, sprint_duration):
				_sprint_exhausted = false

	if not is_equal_approx(stamina, previous_stamina):
		stamina_changed.emit(stamina, sprint_duration)
		if is_node_ready() and is_multiplayer_authority():
			_set_exhaustion_effect(is_zero_approx(stamina))


func _set_exhaustion_effect(is_active: bool) -> void:
	if is_active == _is_exhaustion_effect_active:
		return

	_is_exhaustion_effect_active = is_active
	if is_active:
		heartbeat_player.play()
	else:
		heartbeat_player.stop()

	if is_instance_valid(_exhaustion_vignette_tween):
		_exhaustion_vignette_tween.kill()

	var target_strength := exhaustion_vignette_strength if is_active else 0.0
	var fade_duration := (
		exhaustion_vignette_fade_in_duration
		if is_active
		else exhaustion_vignette_fade_out_duration
	)
	_exhaustion_vignette_tween = create_tween()
	_exhaustion_vignette_tween.tween_property(
		screen_effect_material,
		"shader_parameter/exhaustion_vignette_strength",
		target_strength,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_footsteps(delta: float, has_movement_input: bool, is_sprinting: bool) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not is_multiplayer_authority() or not is_on_floor() or not has_movement_input or horizontal_speed < 0.1:
		_footstep_timer = 0.0
		return

	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return

	_play_footstep()
	_footstep_timer = sprint_step_interval if is_sprinting else walk_step_interval


func _play_footstep() -> void:
	var footstep_player := footstep_players[_next_footstep_player]
	_next_footstep_player = (_next_footstep_player + 1) % footstep_players.size()
	footstep_player.stream = FOOTSTEP_STREAMS[_next_footstep_stream]
	_next_footstep_stream = (_next_footstep_stream + 1) % FOOTSTEP_STREAMS.size()
	footstep_player.volume_db = footstep_volume_db + _footstep_rng.randf_range(
		-footstep_volume_variation_db,
		footstep_volume_variation_db
	)
	footstep_player.pitch_scale = _footstep_rng.randf_range(
		1.0 - footstep_pitch_variation,
		1.0 + footstep_pitch_variation
	)
	footstep_player.play()


func _update_camera_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var movement_ratio := horizontal_speed / maxf(walk_speed, 0.001)
	var target_offset := Vector3.ZERO
	if is_on_floor() and horizontal_speed >= 0.1:
		_head_bob_phase = fposmod(
			_head_bob_phase + delta * head_bob_frequency * TAU * movement_ratio,
			TAU * 2.0
		)
		var amplitude := minf(movement_ratio, 1.0)
		target_offset.x = sin(_head_bob_phase * 0.5) * head_bob_horizontal_amount * amplitude
		target_offset.y = sin(_head_bob_phase) * head_bob_vertical_amount * amplitude

	var blend := 1.0 - exp(-head_bob_smoothing * delta)
	camera.position = camera.position.lerp(_default_camera_position + target_offset, blend)


func _rotate_camera(mouse_delta: Vector2) -> void:
	rotate_y(deg_to_rad(-mouse_delta.x * mouse_sensitivity))
	_pitch = clampf(
		_pitch - mouse_delta.y * mouse_sensitivity,
		minimum_look_angle,
		maximum_look_angle
	)
	head.rotation.x = deg_to_rad(_pitch)


func _set_zoomed(is_zoomed: bool) -> void:
	if is_instance_valid(_zoom_tween):
		_zoom_tween.kill()

	var target_fov := _default_camera_fov * (1.0 - zoom_amount) if is_zoomed else _default_camera_fov
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera, "fov", target_fov, zoom_duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
