class_name PlaceholderEnemy
extends Node3D

signal state_changed(previous_state: State, current_state: State)

enum State {
	RELAXED,
	SUSPICIOUS,
	ATTACKING,
}

const VISION_ATTACK_RANGE_RATIO := 2.0 / 3.0
const CONE_SEGMENTS := 24

@export_group("Vision")
@export_range(1.0, 30.0, 0.5) var vision_range: float = 12.0
@export_range(1.0, 179.0, 1.0) var vision_angle_degrees: float = 70.0
@export_flags_3d_physics var vision_occlusion_mask: int = 1
@export_range(0.0, 2.0, 0.1) var vision_target_height: float = 1.0

@export_group("Hearing")
@export_range(0.0, 30.0, 0.5) var hearing_attack_distance: float = 5.0

@export_group("State Colors")
@export var relaxed_color := Color(0.18, 0.9, 0.28, 1.0)
@export var suspicious_color := Color(1.0, 0.82, 0.12, 1.0)
@export var attacking_color := Color(0.95, 0.08, 0.06, 1.0)
@export var vision_cone_color := Color(1.0, 0.84, 0.18, 0.16)

@onready var body: MeshInstance3D = $Body
@onready var vision_origin: Marker3D = $VisionOrigin
@onready var vision_cone: MeshInstance3D = $VisionCone

var current_state: State = State.RELAXED
var _body_material: StandardMaterial3D


func _ready() -> void:
	var source_material := body.get_active_material(0) as StandardMaterial3D
	assert(source_material != null, "The placeholder enemy requires a StandardMaterial3D.")
	_body_material = source_material.duplicate() as StandardMaterial3D
	body.material_override = _body_material
	_build_vision_cone()
	_apply_state_color()


func _physics_process(_delta: float) -> void:
	_set_state(_detect_state())


func _detect_state() -> State:
	var detected_state := State.RELAXED
	for target_node in get_tree().get_nodes_in_group(&"players"):
		var target := target_node as Node3D
		if target == null:
			continue

		var visual_state := _get_visual_detection_state(
			target.global_position,
			_has_clear_line_of_sight(target)
		)
		if visual_state == State.ATTACKING:
			return State.ATTACKING
		if visual_state == State.SUSPICIOUS:
			detected_state = State.SUSPICIOUS

	for emitter_node in get_tree().get_nodes_in_group(&"detectable_sound_emitters"):
		var emitter := emitter_node as Node3D
		if emitter == null:
			continue

		var hearing_state := _get_hearing_detection_state(
			_horizontal_distance_to(emitter.global_position),
			float(emitter.get("current_sound_radius"))
		)
		if hearing_state == State.ATTACKING:
			return State.ATTACKING
		if hearing_state == State.SUSPICIOUS:
			detected_state = State.SUSPICIOUS

	return detected_state


func _get_visual_detection_state(target_position: Vector3, has_line_of_sight: bool) -> State:
	if not has_line_of_sight:
		return State.RELAXED

	var to_target := target_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > vision_range:
		return State.RELAXED
	if is_zero_approx(distance):
		return State.ATTACKING

	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var minimum_dot := cos(deg_to_rad(vision_angle_degrees * 0.5))
	if forward.dot(to_target / distance) < minimum_dot:
		return State.RELAXED

	if distance <= vision_range * VISION_ATTACK_RANGE_RATIO:
		return State.ATTACKING
	return State.SUSPICIOUS


func _get_hearing_detection_state(distance: float, sound_radius: float) -> State:
	if sound_radius <= 0.0 or distance > sound_radius:
		return State.RELAXED
	if distance <= hearing_attack_distance:
		return State.ATTACKING
	return State.SUSPICIOUS


func _has_clear_line_of_sight(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		vision_origin.global_position,
		target.global_position + Vector3.UP * vision_target_height,
		vision_occlusion_mask
	)
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _horizontal_distance_to(target_position: Vector3) -> float:
	var offset := target_position - global_position
	return Vector2(offset.x, offset.z).length()


func _set_state(next_state: State) -> void:
	if current_state == next_state:
		return

	var previous_state := current_state
	current_state = next_state
	_apply_state_color()
	state_changed.emit(previous_state, current_state)


func _apply_state_color() -> void:
	if _body_material == null:
		return

	match current_state:
		State.SUSPICIOUS:
			_body_material.albedo_color = suspicious_color
		State.ATTACKING:
			_body_material.albedo_color = attacking_color
		_:
			_body_material.albedo_color = relaxed_color


func _build_vision_cone() -> void:
	var fill_material := StandardMaterial3D.new()
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_material.albedo_color = vision_cone_color

	var outline_material := fill_material.duplicate() as StandardMaterial3D
	outline_material.albedo_color = Color(
		vision_cone_color.r,
		vision_cone_color.g,
		vision_cone_color.b,
		0.55
	)

	var cone_mesh := ImmediateMesh.new()
	var half_angle := deg_to_rad(vision_angle_degrees * 0.5)
	var cone_height := -0.72
	var origin := Vector3(0.0, cone_height, 0.0)

	cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill_material)
	for segment in CONE_SEGMENTS:
		var angle_a := lerpf(-half_angle, half_angle, float(segment) / CONE_SEGMENTS)
		var angle_b := lerpf(-half_angle, half_angle, float(segment + 1) / CONE_SEGMENTS)
		cone_mesh.surface_add_vertex(origin)
		cone_mesh.surface_add_vertex(_cone_point(angle_a, cone_height))
		cone_mesh.surface_add_vertex(_cone_point(angle_b, cone_height))
	cone_mesh.surface_end()

	cone_mesh.surface_begin(Mesh.PRIMITIVE_LINES, outline_material)
	cone_mesh.surface_add_vertex(origin)
	cone_mesh.surface_add_vertex(_cone_point(-half_angle, cone_height))
	cone_mesh.surface_add_vertex(origin)
	cone_mesh.surface_add_vertex(_cone_point(half_angle, cone_height))
	for segment in CONE_SEGMENTS:
		var angle_a := lerpf(-half_angle, half_angle, float(segment) / CONE_SEGMENTS)
		var angle_b := lerpf(-half_angle, half_angle, float(segment + 1) / CONE_SEGMENTS)
		cone_mesh.surface_add_vertex(_cone_point(angle_a, cone_height))
		cone_mesh.surface_add_vertex(_cone_point(angle_b, cone_height))
	cone_mesh.surface_end()

	vision_cone.mesh = cone_mesh


func _cone_point(angle: float, height: float) -> Vector3:
	return Vector3(sin(angle) * vision_range, height, -cos(angle) * vision_range)
