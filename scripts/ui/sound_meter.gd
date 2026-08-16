class_name SoundMeter
extends Control

const ARC_COUNT := 3
const INACTIVE_COLOR := Color(0.18, 0.24, 0.23, 0.9)
const QUIET_COLOR := Color(0.42, 0.82, 0.68, 1.0)
const LOUD_COLOR := Color(1.0, 0.32, 0.12, 1.0)

@onready var radius_label: Label = $RadiusLabel

var _current_radius: float = 0.0
var _maximum_radius: float = 1.0


func _ready() -> void:
	_update_label()
	queue_redraw()


func set_sound_radius(current_radius: float, maximum_radius: float) -> void:
	_maximum_radius = maxf(maximum_radius, 0.001)
	_current_radius = clampf(current_radius, 0.0, _maximum_radius)
	if is_node_ready():
		_update_label()
	queue_redraw()


func _update_label() -> void:
	if is_zero_approx(_current_radius):
		radius_label.text = "SILENT"
		return
	radius_label.text = "AUDIBLE  %.1f m" % _current_radius


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.025, 0.025, 0.76), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.19, 0.29, 0.27, 0.8), false, 1.0)

	var center := Vector2(size.x * 0.5, 44.0)
	var strength := clampf(_current_radius / _maximum_radius, 0.0, 1.0)
	var active_color := QUIET_COLOR.lerp(LOUD_COLOR, strength)
	draw_circle(center, 3.0, active_color if strength > 0.0 else INACTIVE_COLOR)

	for arc_index in ARC_COUNT:
		var color := (
			active_color if strength > float(arc_index) / float(ARC_COUNT) else INACTIVE_COLOR
		)
		var radius := 11.0 + float(arc_index) * 8.0
		draw_arc(center, radius, -PI / 3.0, PI / 3.0, 18, color, 2.0, true)
		draw_arc(center, radius, PI * 2.0 / 3.0, PI * 4.0 / 3.0, 18, color, 2.0, true)
