extends Node

@export var move_speed_mps: float = 2.0
@export var deadzone: float = 0.2
@export var right_stick_action: StringName = &"primary"

func _physics_process(delta: float) -> void:
	var origin := get_parent() as Node3D
	if origin == null:
		return

	var controller := XRHelpers.get_right_controller(origin)
	if controller == null or not controller.get_is_active():
		return

	var stick: Vector2 = controller.get_vector2(right_stick_action)
	if stick.length() < deadzone:
		return

	var camera := origin.get_node_or_null("XRCamera3D") as XRCamera3D
	var yaw_basis := origin.global_transform.basis
	if camera != null:
		var yaw := camera.global_transform.basis.get_euler().y
		yaw_basis = Basis(Vector3.UP, yaw)

	var move_local := Vector3(stick.x, 0.0, -stick.y)
	var move_world := yaw_basis * move_local
	origin.global_position += move_world * (move_speed_mps * delta)
