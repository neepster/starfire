## Projectile.gd — Animated projectile for slow-combat mode.
## Spawned by Ship.fire_at(); applies damage via the `arrived` signal callback.
class_name Projectile
extends Node2D

signal arrived

const TRAIL_LENGTH := 6

var _target: Vector2
var _speed: float
var _color: Color
var _radius: float
var _is_missile: bool
var _trail: Array[Vector2] = []


## Call this immediately after adding to the scene tree.
func launch(from: Vector2, to: Vector2, speed: float, color: Color,
		radius: float, missile: bool) -> void:
	global_position = from
	_target = to
	_speed = speed
	_color = color
	_radius = radius
	_is_missile = missile


func _process(delta: float) -> void:
	if _is_missile:
		_trail.append(global_position)
		if _trail.size() > TRAIL_LENGTH:
			_trail.pop_front()

	var diff := _target - global_position
	if diff.length() <= _speed * delta:
		global_position = _target
		arrived.emit()
		set_process(false)
		queue_free()
		return

	global_position += diff.normalized() * _speed * delta
	queue_redraw()


func _draw() -> void:
	# Fading trail for missiles
	if _is_missile:
		for i in _trail.size():
			var local_pos := to_local(_trail[i])
			var alpha := float(i + 1) / float(TRAIL_LENGTH + 1) * 0.55
			draw_circle(local_pos, _radius * 0.5,
					Color(_color.r, _color.g, _color.b, alpha))

	# Main projectile dot
	draw_circle(Vector2.ZERO, _radius, _color)
