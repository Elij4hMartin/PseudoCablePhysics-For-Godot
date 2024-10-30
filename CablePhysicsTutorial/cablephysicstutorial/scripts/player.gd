extends CharacterBody3D
# Child nodes
@onready var head := $Head
@onready var camera := $Head/Camera3D
@onready var hand := $Head/Camera3D/Hand
@onready var raycast := $Head/Camera3D/RayCast3D
# this is the position grabbable objects are held at
@onready var hold_point := $Head/Camera3D/Hand/HoldPosition
# Player HUD
@export var active = true
@export_group("Player HUD")
@export var HUD : Control
@export var crosshair : Control
@export var note_HUD : Control
@export var note_text : Control
# Editable values
@export_group("Player Controller Settings")
@export var walk_speed = 5.0 # m/s
@export var hold_walk_amp = 0.5 # multiplier
@export var sprint_walk_amp = 1.5 # multiplier
@export var gravity_scale = 1.0 # multiplier
var speed_modifier = 1.0
@export_subgroup("Camera Settings")
@export var mouse_sensitivity = 0.005 # radians/pixel
@export var camera_min_angle = -80 # degrees
@export var camera_max_angle = 80 # degrees
# Fov variables
@export var base_fov = 85.0 # degrees
@export var fov_change = 1.5 # multiplier
# Head bob variables
@export var bob_freq = 2.0 # frequency
@export var bob_amp = 0.08 # multiplier
@export var bob_amp_hand = 0.03 # multiplier

# Realtime variables
var t_bob = 0.0 # headbob delta_t
var a_bob = 0.0 # headbob current amplitude
var speed = 0.0 # current m/s
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_scale
var prev_velocity = 0.0
var ray_col : Object
var held_object : Object
var holding_object = false
@onready var defualt_hold_position = hold_point.position
# Gamemode variables
var displaying_note = false

# FPS mouse camera control
func _unhandled_input(event):
	# Mouse mode 2 = MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and active:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(camera_min_angle), deg_to_rad(camera_max_angle))

# need to move the held object every frame (not physics) or it looks jittery
func _process(delta: float) -> void:
	# special logic for grabbing that needs to be here or it causes stutter
	if holding_object and held_object != null:
		crosshair._update_crosshair("closed")
		# if moving quickly don't tween!
		if velocity.length() < 1.0:
			held_object.global_transform.origin = lerp(held_object.global_transform.origin, hold_point.global_transform.origin, 12.0 * delta)
		else:
			held_object.global_transform.origin = hold_point.global_transform.origin
		# rotate object towards where camera is facing
		if Input.is_action_pressed("secondary_action"):
			held_object.global_rotation = lerp(held_object.global_rotation, hold_point.global_rotation, 15.0 * delta)

# core logic for player controller
func _physics_process(delta):
	# Update these HUD elements even when not active (sleeping)
	if displaying_note:
		# hide note
		if Input.is_action_just_pressed("secondary_action"):
			active = true
			displaying_note = false
			note_HUD.visible = false
	
	if active:
		if Input.is_action_just_pressed("primary_action"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if Input.is_action_just_pressed("escape"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		HUD.visible = true
		# input movement direction, speed, and delta time
		_walk(_get_player_movement_input(), _sprint(speed), delta)
		_gravity(delta)
		# animate game feel
		_game_feel(delta)
		# grab items and interact with environment
		_handle_grabbing_and_interacting()
		# move character body
		move_and_slide()
	else:
		HUD.visible = false

func _get_player_movement_input() -> Vector3:
	# Get the input direction and handle the movement/deceleration.
	# Turn inputs into a Vector3
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Use camera rotation combined with movement vector3 and convert it into a directional unit Vector3
	var direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	return direction

func _walk(direction: Vector3, current_speed: float, delta: float):	
	if is_on_floor():
		if direction:
			# if movement/inputs detected
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			# no movement/inputs
			velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * current_speed, delta * 7.0)
	else:
		# when in air
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta * 3.0)

func _sprint(current_speed: float):
	if Input.is_action_pressed("sprint"):
		if holding_object:
			current_speed = walk_speed * sprint_walk_amp * hold_walk_amp * speed_modifier
		else:
			# sprint by taking the walk speed and multiplying it by the sprint amplitude
			current_speed = walk_speed * sprint_walk_amp * speed_modifier
	else:
		if holding_object:
			current_speed = walk_speed * hold_walk_amp * speed_modifier
		else:
			current_speed = walk_speed * speed_modifier
	return current_speed

func _gravity(delta: float):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

func _game_feel(delta: float):
	prev_velocity = velocity.y
	
	# Head bob amplitude
	a_bob = lerp(a_bob, Vector2(velocity.x, velocity.z).length() * float(is_on_floor()), delta * 6.0)
	# head bob delta time
	t_bob += delta * a_bob
	camera.transform.origin = _headbob(t_bob, bob_amp * a_bob/4)
	hand.transform.origin = _headbob(t_bob, bob_amp_hand * a_bob/4)
		
	# Adjust FOV proportionally by speed
	var velocity_clamped = clamp(velocity.length(), 0.5, walk_speed * sprint_walk_amp * 2)
	var target_fov = base_fov + fov_change * velocity_clamped
	# Smoothly change camera FOV
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func _headbob(time, magnitude) -> Vector3:
	var pos = Vector3.ZERO
	# offset from local coordinates
	pos.y = sin(time * bob_freq) * magnitude
	pos.x = sin(time * bob_freq / 2) * magnitude
	return pos

func _handle_grabbing_and_interacting():
	if held_object == null:
		holding_object = false
	# Grab/Interact logic may clean this up later
	if raycast.is_colliding():
		if head.global_position.distance_to(raycast.get_collision_point()) <= 1.0:
			hold_point.position.z = -head.global_position.distance_to(raycast.get_collision_point()) * 0.75
			clamp(hold_point.position.z, -1, -0.2)
	else :
		hold_point.position = defualt_hold_position
	if holding_object and (Input.is_action_just_pressed("primary_action") or Input.is_action_just_pressed("throw")) and held_object != null:
		_drop_or_throw_item(Input.is_action_just_pressed("throw"))
	
	ray_col = raycast.get_collider()
	if ray_col != null:
		if ray_col.is_in_group("Grabbable"):
			#update crosshair
			crosshair._update_crosshair("open")
		elif ray_col.is_in_group("Interactable"):
			#update crosshair
			crosshair._update_crosshair("point")
		elif holding_object == false:
			#update crosshair
			crosshair._update_crosshair("crosshair")
		if Input.is_action_just_pressed("primary_action"):
			if ray_col.is_in_group("Grabbable") and holding_object == false:
				# grab object
				holding_object = true
				held_object = raycast.get_collider()
				#update crosshair
				crosshair._update_crosshair("closed")
				#held_object.disable_mode = RigidBody3D.DISABLE_MODE_MAKE_STATIC
				held_object.set_collision_layer_value(3, false)
				held_object.freeze = false
			if ray_col.is_in_group("Interactable"):
				#press object
				ray_col._interact()
				#update crosshair
				crosshair._update_crosshair("closed")
	else:
		crosshair._update_crosshair("crosshair")

func _drop_or_throw_item(throwing):
	if holding_object:
		# throw object towards the direction the camera is facing, throw proportionally to how fast the player is moving
		if throwing:
			# throw
			held_object.linear_velocity = (hold_point.global_position - global_position).normalized() * 5.0
		else:
			# drop
			held_object.linear_velocity = Vector3(0, 0, 0)
		held_object.set_angular_velocity(Vector3(0, 0, 0))
		held_object.set_collision_layer_value(3, true)
		held_object.freeze = false
		# drop object
		holding_object = false
		# set held object to null
		held_object = null

func _display_note(message_text):
	active = false
	displaying_note = true
	note_HUD.visible = true
	note_text.text = message_text

func _display_popup(message_text):
	$Head/Camera3D/PlayerHUD/PopUpMessage._display_message(message_text)
