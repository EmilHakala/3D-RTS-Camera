extends Camera3D

# Camera movement settings
@export_category("Camera movement settings")
## Defines the speed of camera movement.
@export var camera_speed: float = 20.0
## Defines how fast the camera can zoom.
@export var camera_zoom_speed: float = 20.0
## Defines how close you can zoom the camera.
@export var camera_zoom_min: float = 10.0
## Defines how far away you can zoom the camera.
@export var camera_zoom_max: float = 50.0

#Edge scrolling settings
@export_category("Edge scrolling settings")
## Defines how close to the edge the mouse has to be for the edge scrolling to trigger.
@export var edge_scroll_margin: float = 20.0
## Defines the speed of the edge scrolling.
@export var edge_scroll_speed: float = 15.0

# Camera rotation settings
@export_category("Camera rotation settings")
## Defines how fast the camera rotates.
@export var rotation_speed: float = 2.0

# Current camera properties
var current_height: float = 20.0
var orbit_center: Vector3 = Vector3.ZERO
var orbit_radius: float = 20.0

func _ready():
	# Set initial position and rotation
	_update_camera_position()
	rotation_degrees.x = -45  # Tilt the camera down 45 degrees

func _process(delta):
	var movement = Vector3.ZERO
	
	# Keyboard movement
	if Input.is_action_pressed("ui_right"):
		movement.x += 1
	if Input.is_action_pressed("ui_left"):
		movement.x -= 1
	if Input.is_action_pressed("ui_up"):
		movement.z -= 1
	if Input.is_action_pressed("ui_down"):
		movement.z += 1
	
	# Edge scrolling
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().size
	
	if mouse_pos.x < edge_scroll_margin:
		movement.x -= 1
	elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
		movement.x += 1
	if mouse_pos.y < edge_scroll_margin:
		movement.z -= 1
	elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
		movement.z += 1
	
	# Move the orbit center instead of the camera directly
	if movement.length() > 0:
		movement = movement.normalized()
		movement = movement.rotated(Vector3.UP, rotation.y)
		orbit_center += movement * camera_speed * delta
		_update_camera_position()

func _unhandled_input(event):
	# Camera zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_height = max(camera_zoom_min, current_height - camera_zoom_speed * get_process_delta_time())
			orbit_radius = current_height * 1.5  # Adjust radius based on height
			_update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_height = min(camera_zoom_max, current_height + camera_zoom_speed * get_process_delta_time())
			orbit_radius = current_height * 1.5  # Adjust radius based on height
			_update_camera_position()
		
	# Camera rotation with middle mouse button
	elif event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_RIGHT:
		rotate_y(-event.relative.x * rotation_speed * get_process_delta_time())
		_update_camera_position()

func _update_camera_position():
	# Calculate the camera's position based on its orbit parameters
	var angle = rotation.y
	var offset = Vector3(
		sin(angle) * orbit_radius,
		current_height,
		cos(angle) * orbit_radius
	)
	position = orbit_center + offset
	# Make the camera look at the orbit center
	look_at(orbit_center, Vector3.UP)
