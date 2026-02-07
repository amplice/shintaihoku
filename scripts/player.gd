extends CharacterBody3D

## Player controller with third-person camera and WASD movement.

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const ROTATION_SPEED = 0.003
const GRAVITY = 20.0
const JUMP_VELOCITY = 7.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var camera_rotation_x: float = -0.3  # slight downward angle
var ps1_shader: Shader

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ps1_shader = load("res://shaders/ps1.gdshader")
	_build_humanoid_model()

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

	# Jump
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

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

func _build_humanoid_model() -> void:
	# Remove the old capsule mesh from the scene
	var old_mesh := get_node_or_null("MeshInstance3D")
	if old_mesh:
		old_mesh.queue_free()

	var model := Node3D.new()
	model.name = "Model"
	add_child(model)

	var skin_color := Color(0.85, 0.72, 0.6)
	var jacket_color := Color(0.12, 0.12, 0.15)
	var pants_color := Color(0.1, 0.1, 0.12)
	var accent_cyan := Color(0.0, 0.9, 1.0)

	# Head
	_add_body_part(model, "Head", SphereMesh.new(), Vector3(0, 1.55, 0), skin_color)
	(model.get_node("Head").mesh as SphereMesh).radius = 0.18
	(model.get_node("Head").mesh as SphereMesh).height = 0.36

	# Torso
	_add_body_part(model, "Torso", BoxMesh.new(), Vector3(0, 1.1, 0), jacket_color,
		Vector3(0.5, 0.55, 0.28))

	# Accent stripe on chest (thin emissive cyan strip)
	_add_body_part(model, "AccentStripe", BoxMesh.new(), Vector3(0, 1.05, 0.141), accent_cyan,
		Vector3(0.3, 0.06, 0.01), true, accent_cyan, 3.0)

	# Hips
	_add_body_part(model, "Hips", BoxMesh.new(), Vector3(0, 0.75, 0), pants_color,
		Vector3(0.45, 0.2, 0.25))

	# Left upper arm
	_add_body_part(model, "LeftUpperArm", BoxMesh.new(), Vector3(-0.32, 1.15, 0), jacket_color,
		Vector3(0.13, 0.3, 0.13))
	# Left lower arm
	_add_body_part(model, "LeftLowerArm", BoxMesh.new(), Vector3(-0.32, 0.85, 0), skin_color,
		Vector3(0.12, 0.3, 0.12))
	# Right upper arm
	_add_body_part(model, "RightUpperArm", BoxMesh.new(), Vector3(0.32, 1.15, 0), jacket_color,
		Vector3(0.13, 0.3, 0.13))
	# Right lower arm
	_add_body_part(model, "RightLowerArm", BoxMesh.new(), Vector3(0.32, 0.85, 0), skin_color,
		Vector3(0.12, 0.3, 0.12))

	# Left upper leg
	_add_body_part(model, "LeftUpperLeg", BoxMesh.new(), Vector3(-0.12, 0.5, 0), pants_color,
		Vector3(0.15, 0.33, 0.15))
	# Left lower leg
	_add_body_part(model, "LeftLowerLeg", BoxMesh.new(), Vector3(-0.12, 0.17, 0), pants_color,
		Vector3(0.14, 0.33, 0.14))
	# Right upper leg
	_add_body_part(model, "RightUpperLeg", BoxMesh.new(), Vector3(0.12, 0.5, 0), pants_color,
		Vector3(0.15, 0.33, 0.15))
	# Right lower leg
	_add_body_part(model, "RightLowerLeg", BoxMesh.new(), Vector3(0.12, 0.17, 0), pants_color,
		Vector3(0.14, 0.33, 0.14))

func _add_body_part(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3,
		color: Color, box_size: Vector3 = Vector3.ZERO, is_emissive: bool = false,
		emit_color: Color = Color.BLACK, emit_strength: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.position = pos

	if mesh is BoxMesh and box_size != Vector3.ZERO:
		(mesh as BoxMesh).size = box_size

	var mat := ShaderMaterial.new()
	mat.shader = ps1_shader
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("vertex_snap_intensity", 4.0)
	mat.set_shader_parameter("color_depth", 12.0)
	mat.set_shader_parameter("fog_color", Color(0.05, 0.03, 0.1, 1.0))
	mat.set_shader_parameter("fog_distance", 100.0)
	mat.set_shader_parameter("fog_density", 0.8)
	if is_emissive:
		mat.set_shader_parameter("emissive", true)
		mat.set_shader_parameter("emission_color", emit_color)
		mat.set_shader_parameter("emission_strength", emit_strength)
	mi.set_surface_override_material(0, mat)

	parent.add_child(mi)
