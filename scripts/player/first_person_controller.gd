class_name FirstPersonController
extends CharacterBody3D

signal stamina_changed(current_stamina: float, maximum_stamina: float)
signal sound_radius_changed(current_radius: float, maximum_radius: float)

const FOOTSTEP_STREAMS: Array[AudioStream] = [
	preload("res://sounds/footsteps/data_pion-st1-footstep-sfx-323053.mp3"),
	preload("res://sounds/footsteps/data_pion-st2-footstep-sfx-323055.mp3"),
	preload("res://sounds/footsteps/data_pion-st3-footstep-sfx-323056.mp3"),
]

@export_group("Movement")
@export var walk_speed: float = 2.5
@export var sprint_speed: float = 3.8
@export var crouch_speed: float = 1.25
@export var ground_acceleration: float = 10.0
@export var air_acceleration: float = 3.0
@export_range(1.0, 30.0, 0.5) var movement_input_smoothing_speed: float = 10.0
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
@export_range(0.0, 3.0, 0.05) var sprint_noise_fade_in_duration: float = 0.45
@export_range(0.0, 3.0, 0.05) var sprint_noise_fade_out_duration: float = 1.2

@export_group("Footsteps")
@export_range(0.1, 1.0, 0.01) var walk_step_interval: float = 0.44
@export_range(0.1, 1.0, 0.01) var sprint_step_interval: float = 0.34
@export_range(-40.0, 0.0, 0.5) var footstep_volume_db: float = -22.0
@export_range(0.0, 20.0, 0.5) var crouch_footstep_attenuation_db: float = 10.0
@export_range(0.0, 6.0, 0.1) var footstep_volume_variation_db: float = 1.5
@export_range(0.0, 0.25, 0.01) var footstep_pitch_variation: float = 0.05

@export_group("Sound Detection")
## Enemy hearing radius in meters while moving in a crouch.
@export_range(0.0, 30.0, 0.5) var crouch_sound_radius: float = 2.0
## Enemy hearing radius in meters while walking.
@export_range(0.0, 30.0, 0.5) var walk_sound_radius: float = 5.0
## Enemy hearing radius in meters while sprinting.
@export_range(0.0, 30.0, 0.5) var sprint_sound_radius: float = 9.0

@export_group("Camera")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.08
@export_range(1.0, 30.0, 0.5) var mouse_look_smoothing_speed: float = 5.0
@export_range(-89.0, 0.0, 1.0) var minimum_look_angle: float = -89.0
@export_range(0.0, 89.0, 1.0) var maximum_look_angle: float = 89.0
@export_range(0.0, 0.9, 0.01) var zoom_amount: float = 0.6
@export_range(0.1, 10.0, 0.1) var zoom_duration: float = 0.7

@export_group("Camera Lean")
## Sideways camera displacement in meters at full lean.
@export_range(0.0, 0.5, 0.01) var lean_horizontal_amount: float = 0.18
## Downward camera displacement in meters at full lean.
@export_range(0.0, 0.2, 0.005) var lean_vertical_drop: float = 0.025
## Camera tilt in degrees at full lean.
@export_range(0.0, 20.0, 0.5) var lean_roll_amount: float = 7.0
## Lean responsiveness; higher values enter and leave the lean more quickly.
@export_range(1.0, 20.0, 0.5) var lean_transition_speed: float = 8.0
## Sideways balance sway in meters while leaning.
@export_range(0.0, 0.05, 0.001) var lean_sway_position_amount: float = 0.008
## Additional balance sway in degrees while leaning.
@export_range(0.0, 2.0, 0.05) var lean_sway_roll_amount: float = 0.35
## Speed of the balance sway while leaning.
@export_range(0.05, 3.0, 0.05) var lean_sway_frequency: float = 0.9

@export_group("Walking Camera Bob")
## Vertical camera displacement in meters; higher values create more bounce.
@export_range(0.0, 0.1, 0.005) var head_bob_vertical_amount: float = 0.035
## Side-to-side camera displacement in meters; higher values create a wider sway.
@export_range(0.0, 0.1, 0.005) var head_bob_horizontal_amount: float = 0.02
## Base stride cadence; higher values make walking and sprinting bob faster.
@export_range(0.1, 5.0, 0.1) var head_bob_frequency: float = 2.0
## Bob responsiveness; higher values feel sharper and lower values feel floatier.
@export_range(1.0, 20.0, 0.5) var head_bob_smoothing: float = 10.0
## Multiplier applied to movement bob while stamina is empty.
@export_range(1.0, 3.0, 0.05) var exhaustion_bob_multiplier: float = 2.2
## Forward and backward camera nod in degrees while walking.
@export_range(0.0, 3.0, 0.05) var walk_bob_pitch_amount: float = 0.25
## Sideways camera tilt in degrees while walking.
@export_range(0.0, 5.0, 0.05) var walk_bob_roll_amount: float = 0.45
## Footfall shape; zero is smooth and higher values create a sharper downward step.
@export_range(0.0, 0.5, 0.01) var walk_bob_impact_sharpness: float = 0.1

@export_group("Sprint Camera Bob")
## Multiplier applied to the walking vertical displacement at full sprint.
@export_range(1.0, 3.0, 0.05) var sprint_bob_vertical_multiplier: float = 1.8
## Multiplier applied to the walking side-to-side displacement at full sprint.
@export_range(1.0, 3.0, 0.05) var sprint_bob_horizontal_multiplier: float = 1.4
## Forward and backward camera nod in degrees at full sprint.
@export_range(0.0, 5.0, 0.05) var sprint_bob_pitch_amount: float = 0.9
## Sideways camera tilt in degrees at full sprint.
@export_range(0.0, 8.0, 0.05) var sprint_bob_roll_amount: float = 1.25
## Running footfall shape; higher values create a heavier, sharper impact.
@export_range(0.0, 0.5, 0.01) var sprint_bob_impact_sharpness: float = 0.25
## Walk-to-sprint blend speed; higher values transition more quickly.
@export_range(0.1, 20.0, 0.1) var sprint_bob_transition_speed: float = 7.0

@export_group("Idle Camera Sway")
@export_range(0.0, 0.05, 0.001) var idle_sway_vertical_amount: float = 0.016
@export_range(0.0, 0.05, 0.001) var idle_sway_horizontal_amount: float = 0.022
@export_range(0.05, 2.0, 0.05) var idle_sway_frequency: float = 0.20

@export_group("Handheld Camera Sway")
@export_range(0.0, 3.0, 0.05) var handheld_sway_pitch_amount: float = 0.35
@export_range(0.0, 3.0, 0.05) var handheld_sway_yaw_amount: float = 0.45
@export_range(0.0, 5.0, 0.05) var handheld_sway_roll_amount: float = 0.6
@export_range(0.05, 2.0, 0.05) var handheld_sway_frequency: float = 0.15
@export_range(1.0, 20.0, 0.5) var handheld_sway_smoothing: float = 6.0

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
@onready var screen_filter: ColorRect = $VHSScreenEffect/ScreenFilter
@onready var screen_effect_material: ShaderMaterial = screen_filter.material
@onready var sprint_noise_effect: CanvasLayer = $SprintVHSNoiseEffect
@onready var sprint_noise_filter: ColorRect = $SprintVHSNoiseEffect/ScreenFilter
@onready var sprint_noise_material: ShaderMaterial = sprint_noise_filter.material
@onready var heartbeat_player: AudioStreamPlayer = $HeartbeatPlayer
@onready var footstep_players: Array[AudioStreamPlayer] = [
	$FootstepPlayerA,
	$FootstepPlayerB,
]

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _smoothed_movement_input := Vector2.ZERO
var _pitch: float = 0.0
var _target_pitch: float = 0.0
var _target_yaw: float = 0.0
var _default_camera_fov: float
var _default_camera_position: Vector3
var _default_camera_rotation: Vector3
var _standing_head_position: Vector3
var _standing_collision_position: Vector3
var _standing_body_position: Vector3
var _standing_height: float
var _target_stance_height: float
var _collision_capsule: CapsuleShape3D
var _body_capsule_mesh: CapsuleMesh
var _standing_clearance_shape: CapsuleShape3D
var _head_bob_phase: float = 0.0
var _idle_sway_phase: float = 0.0
var _handheld_sway_phase: float = 0.0
var _sprint_bob_weight: float = 0.0
var _lean_amount: float = 0.0
var _lean_sway_phase: float = 0.0
var _zoom_tween: Tween
var _footstep_timer: float = 0.0
var _next_footstep_player: int = 0
var _next_footstep_stream: int = 0
var _footstep_rng := RandomNumberGenerator.new()
var stamina: float = 0.0
var current_sound_radius: float = 0.0:
	set(value):
		var clamped_radius := clampf(value, 0.0, get_max_sound_radius())
		if is_equal_approx(current_sound_radius, clamped_radius):
			return
		current_sound_radius = clamped_radius
		sound_radius_changed.emit(current_sound_radius, get_max_sound_radius())
var _stamina_regeneration_cooldown: float = 0.0
var _sprint_exhausted: bool = false
var _sprint_noise_tween: Tween
var _is_sprint_noise_effect_active := false
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
	_pitch = rad_to_deg(head.rotation.x)
	_target_pitch = _pitch
	_target_yaw = rotation.y
	stamina = sprint_duration
	stamina_changed.emit(stamina, sprint_duration)
	_default_camera_fov = camera.fov
	_default_camera_position = camera.position
	_default_camera_rotation = camera.rotation
	_cache_stance_geometry()
	_apply_stance(is_crouching, true)
	set_physics_process(is_local_player)
	set_process(is_local_player)
	set_process_unhandled_input(is_local_player)
	camera.current = is_local_player
	interaction_ray.enabled = is_local_player
	body_mesh.visible = not is_local_player
	screen_filter.visible = is_local_player
	sprint_noise_effect.visible = false
	if is_local_player:
		_configure_fog()
		sprint_noise_material.set_shader_parameter("effect_opacity", 0.0)
		screen_effect_material.set_shader_parameter("exhaustion_vignette_strength", 0.0)
		var heartbeat_stream := heartbeat_player.stream.duplicate() as AudioStreamMP3
		heartbeat_stream.loop = true
		heartbeat_player.stream = heartbeat_stream
		_footstep_rng.randomize()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var blend := 1.0 - exp(-mouse_look_smoothing_speed * delta)
	rotation.y = lerp_angle(rotation.y, _target_yaw, blend)
	_pitch = lerpf(_pitch, _target_pitch, blend)
	head.rotation.x = deg_to_rad(_pitch)


func _configure_fog() -> void:
	if not is_multiplayer_authority():
		return

	var world_environment := get_world_3d().environment
	if world_environment == null:
		return

	var local_environment := world_environment.duplicate() as Environment
	local_environment.fog_enabled = fog_enabled
	local_environment.fog_mode = fog_mode as Environment.FogMode
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
	var input_blend := 1.0 - exp(-movement_input_smoothing_speed * delta)
	_smoothed_movement_input = _smoothed_movement_input.lerp(input_direction, input_blend)
	if _smoothed_movement_input.distance_squared_to(input_direction) < 0.000001:
		_smoothed_movement_input = input_direction
	var local_direction := Vector3(
		_smoothed_movement_input.x,
		0.0,
		_smoothed_movement_input.y
	)
	var movement_direction := transform.basis * local_direction
	_update_crouch_state(Input.is_action_pressed("crouch"))
	_update_crouch_transition(delta)
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
	_set_sprint_noise_effect(is_sprinting)
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
	_update_sound_radius(not input_direction.is_zero_approx(), is_sprinting)
	_update_footsteps(delta, not input_direction.is_zero_approx(), is_sprinting)
	var lean_input := Input.get_axis("lean_left", "lean_right")
	_update_camera_motion(delta, is_sprinting, lean_input)


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
	_target_stance_height = _standing_height


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


func _apply_stance(crouching: bool, snap_transition: bool = false) -> void:
	_target_stance_height = (
		maxf(crouch_height, _collision_capsule.radius * 2.0) if crouching else _standing_height
	)
	if snap_transition:
		_set_stance_height(_target_stance_height)


func _update_crouch_transition(delta: float) -> void:
	var blend := 1.0 - exp(-crouch_transition_speed * delta)
	var height := lerpf(_collision_capsule.height, _target_stance_height, blend)
	if absf(height - _target_stance_height) < 0.001:
		height = _target_stance_height
	_set_stance_height(height)


func _set_stance_height(height: float) -> void:
	var height_difference := _standing_height - height
	_collision_capsule.height = height
	collision_shape.position = _standing_collision_position - Vector3.UP * height_difference * 0.5
	_body_capsule_mesh.height = height
	body_mesh.position = _standing_body_position - Vector3.UP * height_difference * 0.5
	head.position = _standing_head_position - Vector3.UP * height_difference


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


func _set_sprint_noise_effect(is_active: bool) -> void:
	if is_active == _is_sprint_noise_effect_active:
		return

	_is_sprint_noise_effect_active = is_active
	if is_active:
		sprint_noise_effect.visible = true

	if is_instance_valid(_sprint_noise_tween):
		_sprint_noise_tween.kill()

	var fade_duration := (
		sprint_noise_fade_in_duration if is_active else sprint_noise_fade_out_duration
	)
	_sprint_noise_tween = create_tween()
	_sprint_noise_tween.tween_property(
		sprint_noise_material,
		"shader_parameter/effect_opacity",
		1.0 if is_active else 0.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not is_active:
		_sprint_noise_tween.tween_callback(_hide_sprint_noise_effect)


func _hide_sprint_noise_effect() -> void:
	if not _is_sprint_noise_effect_active:
		sprint_noise_effect.visible = false


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


func get_max_sound_radius() -> float:
	return maxf(crouch_sound_radius, maxf(walk_sound_radius, sprint_sound_radius))


func _get_movement_sound_radius(
	has_movement_input: bool,
	is_grounded: bool,
	is_sprinting: bool
) -> float:
	if not has_movement_input or not is_grounded:
		return 0.0
	if is_sprinting:
		return sprint_sound_radius
	if is_crouching:
		return crouch_sound_radius
	return walk_sound_radius


func _update_sound_radius(has_movement_input: bool, is_sprinting: bool) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	current_sound_radius = _get_movement_sound_radius(
		has_movement_input and horizontal_speed >= 0.1,
		is_on_floor(),
		is_sprinting
	)


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
	var crouch_attenuation := crouch_footstep_attenuation_db if is_crouching else 0.0
	footstep_player.volume_db = footstep_volume_db - crouch_attenuation + _footstep_rng.randf_range(
		-footstep_volume_variation_db,
		footstep_volume_variation_db
	)
	footstep_player.pitch_scale = _footstep_rng.randf_range(
		1.0 - footstep_pitch_variation,
		1.0 + footstep_pitch_variation
	)
	if DisplayServer.get_name() == "headless":
		return
	footstep_player.play()


func _update_camera_motion(delta: float, is_sprinting: bool, lean_input: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var movement_ratio := horizontal_speed / maxf(walk_speed, 0.001)
	var target_offset := Vector3.ZERO
	var target_rotation := _default_camera_rotation
	var lean_blend := 1.0 - exp(-lean_transition_speed * delta)
	_lean_amount = lerpf(_lean_amount, clampf(lean_input, -1.0, 1.0), lean_blend)
	if absf(_lean_amount - lean_input) < 0.001:
		_lean_amount = lean_input
	if is_zero_approx(_lean_amount):
		_lean_sway_phase = 0.0
	else:
		_lean_sway_phase = fposmod(
			_lean_sway_phase + delta * lean_sway_frequency * TAU,
			TAU
		)
	var sprint_blend := 1.0 - exp(-sprint_bob_transition_speed * delta)
	_sprint_bob_weight = lerpf(
		_sprint_bob_weight,
		1.0 if is_sprinting else 0.0,
		sprint_blend
	)
	if is_on_floor() and horizontal_speed >= 0.1:
		_head_bob_phase = fposmod(
			_head_bob_phase + delta * head_bob_frequency * TAU * movement_ratio,
			TAU * 2.0
		)
		var amplitude := minf(movement_ratio, 1.0)
		var exhaustion_multiplier := (
			exhaustion_bob_multiplier if is_zero_approx(stamina) else 1.0
		)
		var horizontal_wave := sin(_head_bob_phase * 0.5)
		var impact_sharpness := lerpf(
			walk_bob_impact_sharpness,
			sprint_bob_impact_sharpness,
			_sprint_bob_weight
		)
		var vertical_wave := (
			sin(_head_bob_phase)
			- impact_sharpness * sin(_head_bob_phase * 2.0)
		)
		var vertical_multiplier := lerpf(
			1.0,
			sprint_bob_vertical_multiplier,
			_sprint_bob_weight
		)
		var horizontal_multiplier := lerpf(
			1.0,
			sprint_bob_horizontal_multiplier,
			_sprint_bob_weight
		)
		target_offset.x = (
			horizontal_wave
			* head_bob_horizontal_amount
			* horizontal_multiplier
			* amplitude
			* exhaustion_multiplier
		)
		target_offset.y = (
			vertical_wave
			* head_bob_vertical_amount
			* vertical_multiplier
			* amplitude
			* exhaustion_multiplier
		)
		var pitch_amount := lerpf(
			walk_bob_pitch_amount,
			sprint_bob_pitch_amount,
			_sprint_bob_weight
		)
		var roll_amount := lerpf(
			walk_bob_roll_amount,
			sprint_bob_roll_amount,
			_sprint_bob_weight
		)
		target_rotation += Vector3(
			deg_to_rad(
				vertical_wave * pitch_amount * amplitude * exhaustion_multiplier
			),
			0.0,
			deg_to_rad(-horizontal_wave * roll_amount * amplitude * exhaustion_multiplier)
		)
	elif is_on_floor():
		_idle_sway_phase = fposmod(
			_idle_sway_phase + delta * idle_sway_frequency * TAU,
			TAU
		)
		target_offset.x = sin(_idle_sway_phase) * idle_sway_horizontal_amount
		target_offset.y = sin(_idle_sway_phase * 2.0) * idle_sway_vertical_amount
		_handheld_sway_phase = fposmod(
			_handheld_sway_phase + delta * handheld_sway_frequency * TAU,
			TAU * 10.0
		)
		var pitch_sway := (
			(sin(_handheld_sway_phase * 0.7) + 0.25 * sin(_handheld_sway_phase * 1.9 + 1.1))
			/ 1.25
		)
		var yaw_sway := (
			(sin(_handheld_sway_phase * 0.5 + 1.7) + 0.2 * sin(_handheld_sway_phase * 1.3))
			/ 1.2
		)
		var roll_sway := (
			(sin(_handheld_sway_phase + 2.4) + 0.15 * sin(_handheld_sway_phase * 2.3))
			/ 1.15
		)
		target_rotation += Vector3(
			deg_to_rad(pitch_sway * handheld_sway_pitch_amount),
			deg_to_rad(yaw_sway * handheld_sway_yaw_amount),
			deg_to_rad(roll_sway * handheld_sway_roll_amount)
		)

	var lean_sway := sin(_lean_sway_phase) * absf(_lean_amount)
	target_offset.x += (
		_lean_amount * lean_horizontal_amount
		+ lean_sway * lean_sway_position_amount
	)
	target_offset.y -= absf(_lean_amount) * lean_vertical_drop
	target_rotation.z += deg_to_rad(
		-_lean_amount * lean_roll_amount
		+ lean_sway * lean_sway_roll_amount
	)

	var position_blend := 1.0 - exp(-head_bob_smoothing * delta)
	var rotation_smoothing := (
		head_bob_smoothing if horizontal_speed >= 0.1 else handheld_sway_smoothing
	)
	rotation_smoothing = maxf(rotation_smoothing, lean_transition_speed)
	var rotation_blend := 1.0 - exp(-rotation_smoothing * delta)
	camera.position = camera.position.lerp(_default_camera_position + target_offset, position_blend)
	camera.rotation = camera.rotation.lerp(target_rotation, rotation_blend)


func _rotate_camera(mouse_delta: Vector2) -> void:
	_target_yaw = wrapf(
		_target_yaw - deg_to_rad(mouse_delta.x * mouse_sensitivity),
		-PI,
		PI
	)
	_target_pitch = clampf(
		_target_pitch - mouse_delta.y * mouse_sensitivity,
		minimum_look_angle,
		maximum_look_angle
	)


func _set_zoomed(is_zoomed: bool) -> void:
	if is_instance_valid(_zoom_tween):
		_zoom_tween.kill()

	var target_fov := _default_camera_fov * (1.0 - zoom_amount) if is_zoomed else _default_camera_fov
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera, "fov", target_fov, zoom_duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
