extends GPUParticles3D

## Rain system that follows the camera.

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position + Vector3(0, 15, 0)
