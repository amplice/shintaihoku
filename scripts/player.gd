extends CharacterBody3D

## Player controller with third-person camera and WASD movement.

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const ROTATION_SPEED = 0.003
const GRAVITY = 20.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var camera_rotation_x: float = -0.3  # slight downward angle

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Horizontal rotation on player body
		rotate_y(-event.relative.x * ROTATION_SPEED)
		# Vertical rotation on camera pivot
		camera_rotation_x -= event.relative.y * ROTATION_SPEED
		camera_rotation_x = clamp(camera_rotation_x, -1.2, 0.5)
		camera_pivot.rotation.x = camera_rotation_x

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0, current_speed * 5.0 * delta)

	move_and_slide()
