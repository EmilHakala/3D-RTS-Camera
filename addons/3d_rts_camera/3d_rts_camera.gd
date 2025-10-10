extends Camera3D

# =========================
# Camera movement settings
# =========================
@export_category("Camera movement")
@export var camera_speed: float = 20.0
@export var camera_zoom_speed: float = 20.0
@export var camera_zoom_min: float = 10.0
@export var camera_zoom_max: float = 50.0

# =========================
# Edge scrolling settings
# =========================
@export_category("Edge scrolling")
@export var edge_scroll_margin: float = 20.0
@export var edge_scroll_speed: float = 15.0  # reserved if you want separate edge weighting later

# =========================
# Rotation (MMB) settings
# =========================
@export_category("Rotation")
# Fractions of a full turn (TAU) for dragging across the *shorter* screen dimension.
# With delta-based scaling, these behave like "per screen-width at 60 FPS".
@export var yaw_sensitivity: float = 0.50
@export var pitch_sensitivity: float = 0.18
@export var max_step_deg: float = 3.0
@export var pitch_min_deg: float = 10.0
@export var pitch_max_deg: float = 80.0
@export var capture_mouse_on_mmb: bool = false

# =========================
# Runtime state
# =========================
var orbit_center: Vector3 = Vector3.ZERO
var orbit_distance: float = 25.0     # zoom applies to this
var current_height: float = 20.0     # derived for reference
var orbit_radius: float = 20.0       # derived for reference

var _is_mmb_rotating := false
var _yaw: float = 0.0
var _pitch: float = 0.8              # radians (~45° initial)

func _ready() -> void:
	var pmin := deg_to_rad(pitch_min_deg)
	var pmax := deg_to_rad(pitch_max_deg)
	_pitch = clamp(_pitch, pmin, pmax)
	_update_camera_position()

func _process(delta: float) -> void:
	var movement := Vector3.ZERO

	# Keyboard movement (uses default ui_* actions)
	if Input.is_action_pressed("ui_right"):
		movement.x += 1
	if Input.is_action_pressed("ui_left"):
		movement.x -= 1
	if Input.is_action_pressed("ui_up"):
		movement.z -= 1
	if Input.is_action_pressed("ui_down"):
		movement.z += 1

	# Edge scrolling
	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size = get_viewport().size
	if mouse_pos.x < edge_scroll_margin:
		movement.x -= 1
	elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
		movement.x += 1
	if mouse_pos.y < edge_scroll_margin:
		movement.z -= 1
	elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
		movement.z += 1

	# Shift boost (make sure you added 'ui_shift' in Input Map)
	var speed_multiplier := 2.0 if Input.is_action_pressed("ui_shift") else 1.0

	# Move orbit center in camera's yaw frame
	if movement.length() > 0.0:
		movement = movement.normalized().rotated(Vector3.UP, _yaw)
		orbit_center += movement * camera_speed * speed_multiplier * delta
		_update_camera_position()

func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel zoom (changes orbit_distance)
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = max(camera_zoom_min, orbit_distance - camera_zoom_speed * get_process_delta_time())
			_update_camera_position()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = min(camera_zoom_max, orbit_distance + camera_zoom_speed * get_process_delta_time())
			_update_camera_position()

		# Start/stop rotate+tilt with Middle Mouse
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_mmb_rotating = event.pressed
			if capture_mouse_on_mmb:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
			# accept_event()  # uncomment if UI shouldn't also consume MMB

	# Delta-based rotation while dragging with MMB
	elif event is InputEventMouseMotion and _is_mmb_rotating:
		var vp = get_viewport().size
		var vmin := float(min(vp.x, vp.y))          # normalize by the shorter side
		var dt := get_process_delta_time()
		var sixty_fps := 60.0 * dt                   # normalize to ~60 FPS feel

		# px -> normalized fraction of screen -> radians, scaled by dt
		var dx = (event.relative.x / vmin) * yaw_sensitivity   * TAU * sixty_fps
		var dy = (event.relative.y / vmin) * pitch_sensitivity * TAU * sixty_fps

		# Safety cap per event
		var max_step := deg_to_rad(max_step_deg)
		dx = clamp(dx, -max_step, max_step)
		dy = clamp(dy, -max_step, max_step)

		_yaw   -= dx
		_pitch += dy   # flip for inverted tilt

		var pmin := deg_to_rad(pitch_min_deg)
		var pmax := deg_to_rad(pitch_max_deg)
		_pitch = clamp(_pitch, pmin, pmax)

		_update_camera_position()

# =========================
# Helpers
# =========================
func _update_camera_position() -> void:
	# Spherical direction from yaw/pitch
	var dir := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	).normalized()

	position = orbit_center + dir * orbit_distance
	look_at(orbit_center, Vector3.UP)

	# Derived values (useful if other systems read them)
	current_height = orbit_distance * sin(_pitch)
	orbit_radius   = orbit_distance * cos(_pitch)
