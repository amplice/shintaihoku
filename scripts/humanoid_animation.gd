class_name HumanoidAnimation
extends RefCounted

## Procedural walk/idle animation for pivot-based humanoid limbs.
## Reusable for player and NPCs.

var left_shoulder: Node3D
var right_shoulder: Node3D
var left_hip: Node3D
var right_hip: Node3D
var left_elbow: Node3D
var right_elbow: Node3D
var left_knee: Node3D
var right_knee: Node3D

var walk_cycle: float = 0.0
var walk_frequency: float = 8.0  # cycles per second at full speed
var is_setup: bool = false

func setup(model: Node3D) -> void:
	left_shoulder = model.get_node_or_null("LeftShoulder")
	right_shoulder = model.get_node_or_null("RightShoulder")
	left_hip = model.get_node_or_null("LeftHip")
	right_hip = model.get_node_or_null("RightHip")
	left_elbow = model.get_node_or_null("LeftShoulder/LeftElbow")
	right_elbow = model.get_node_or_null("RightShoulder/RightElbow")
	left_knee = model.get_node_or_null("LeftHip/LeftKnee")
	right_knee = model.get_node_or_null("RightHip/RightKnee")
	is_setup = (left_shoulder != null and right_shoulder != null
		and left_hip != null and right_hip != null)

func update(delta: float, horizontal_speed: float) -> void:
	if not is_setup:
		return

	var speed_ratio := clampf(horizontal_speed / 8.0, 0.0, 1.0)

	if speed_ratio > 0.05:
		# Walking -- advance cycle
		walk_cycle += delta * walk_frequency * speed_ratio
		var swing_amount := 0.5 * speed_ratio  # radians

		# Arms swing opposite to legs
		var arm_swing := sin(walk_cycle) * swing_amount
		var leg_swing := sin(walk_cycle) * swing_amount

		# Shoulder rotation (arms swing forward/back)
		left_shoulder.rotation.x = arm_swing
		right_shoulder.rotation.x = -arm_swing

		# Elbow bend on back-swing (arm bends when swinging back)
		if left_elbow:
			left_elbow.rotation.x = clampf(-arm_swing * 0.6, -0.8, 0.0)
		if right_elbow:
			right_elbow.rotation.x = clampf(arm_swing * 0.6, -0.8, 0.0)

		# Hip rotation (legs swing forward/back)
		left_hip.rotation.x = -leg_swing
		right_hip.rotation.x = leg_swing

		# Knee bend on back-swing (leg bends when swinging back)
		if left_knee:
			left_knee.rotation.x = clampf(leg_swing * 0.7, 0.0, 0.9)
		if right_knee:
			right_knee.rotation.x = clampf(-leg_swing * 0.7, 0.0, 0.9)
	else:
		# Idle -- lerp all rotations back to 0
		var lerp_speed := 10.0 * delta
		left_shoulder.rotation.x = lerpf(left_shoulder.rotation.x, 0.0, lerp_speed)
		right_shoulder.rotation.x = lerpf(right_shoulder.rotation.x, 0.0, lerp_speed)
		left_hip.rotation.x = lerpf(left_hip.rotation.x, 0.0, lerp_speed)
		right_hip.rotation.x = lerpf(right_hip.rotation.x, 0.0, lerp_speed)
		if left_elbow:
			left_elbow.rotation.x = lerpf(left_elbow.rotation.x, 0.0, lerp_speed)
		if right_elbow:
			right_elbow.rotation.x = lerpf(right_elbow.rotation.x, 0.0, lerp_speed)
		if left_knee:
			left_knee.rotation.x = lerpf(left_knee.rotation.x, 0.0, lerp_speed)
		if right_knee:
			right_knee.rotation.x = lerpf(right_knee.rotation.x, 0.0, lerp_speed)
		walk_cycle = 0.0
