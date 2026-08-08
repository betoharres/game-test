class_name FirstPersonController
extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var ground_acceleration: float = 24.0
@export var air_acceleration: float = 8.0
@export var jump_velocity: float = 7.0

@export_group("Camera")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.1
@export_range(-89.0, 0.0, 1.0) var minimum_look_angle: float = -89.0
@export_range(0.0, 89.0, 1.0) var maximum_look_angle: float = 89.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var body_mesh: MeshInstance3D = $BodyMesh

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _pitch: float = 0.0


func _ready() -> void:
	var is_local_player := is_multiplayer_authority()
	set_physics_process(is_local_player)
	set_process_unhandled_input(is_local_player)
	camera.current = is_local_player
	interaction_ray.enabled = is_local_player
	body_mesh.visible = not is_local_player
	if is_local_player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, movement_direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, movement_direction.z * target_speed, acceleration * delta)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta

	move_and_slide()


func _rotate_camera(mouse_delta: Vector2) -> void:
	rotate_y(deg_to_rad(-mouse_delta.x * mouse_sensitivity))
	_pitch = clampf(
		_pitch - mouse_delta.y * mouse_sensitivity,
		minimum_look_angle,
		maximum_look_angle
	)
	head.rotation.x = deg_to_rad(_pitch)
