class_name FirstPersonController
extends CharacterBody3D

signal stamina_changed(current_stamina: float, maximum_stamina: float)

const FOOTSTEP_STREAMS: Array[AudioStream] = [
	preload("res://sounds/footsteps/data_pion-st1-footstep-sfx-323053.mp3"),
	preload("res://sounds/footsteps/data_pion-st2-footstep-sfx-323055.mp3"),
	preload("res://sounds/footsteps/data_pion-st3-footstep-sfx-323056.mp3"),
]

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var ground_acceleration: float = 24.0
@export var air_acceleration: float = 8.0
@export var jump_velocity: float = 7.0

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
@export_range(-40.0, 0.0, 0.5) var footstep_volume_db: float = -12.0
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

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
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


func _ready() -> void:
	var is_local_player := is_multiplayer_authority()
	stamina = sprint_duration
	stamina_changed.emit(stamina, sprint_duration)
	_default_camera_fov = camera.fov
	_default_camera_position = camera.position
	set_physics_process(is_local_player)
	set_process_unhandled_input(is_local_player)
	camera.current = is_local_player
	interaction_ray.enabled = is_local_player
	body_mesh.visible = not is_local_player
	screen_filter.visible = is_local_player
	if is_local_player:
		screen_effect_material.set_shader_parameter("exhaustion_vignette_strength", 0.0)
		var heartbeat_stream := heartbeat_player.stream.duplicate() as AudioStreamMP3
		heartbeat_stream.loop = true
		heartbeat_player.stream = heartbeat_stream
		_footstep_rng.randomize()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	var sprint_requested := Input.is_action_pressed("sprint")
	if not sprint_requested:
		_sprint_exhausted = false
	var is_sprinting := (
		sprint_requested
		and not input_direction.is_zero_approx()
		and not _sprint_exhausted
		and stamina > 0.0
	)
	_update_stamina(delta, is_sprinting)
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, movement_direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, movement_direction.z * target_speed, acceleration * delta)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta

	move_and_slide()
	_update_footsteps(delta, not input_direction.is_zero_approx(), is_sprinting)
	_update_camera_bob(delta)


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
