extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 5

var mouse_scale_h = 0.1
var mouse_scale_v = 0.1
var mouse_captured = false

var hat_hidden = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false
	elif Input.is_action_just_pressed("mouse_left"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
		
	if Input.is_action_just_pressed("ui_text_submit"):
		hat_hidden = !hat_hidden
		$hat.visible = hat_hidden


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_rigth", "move_forward", "move_backwards")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(deg_to_rad(-event.relative.x * mouse_scale_h))
		$cameraArm.rotate_x(deg_to_rad(-event.relative.y * mouse_scale_v))
		$cameraArm.rotation.x = clamp($cameraArm.rotation.x, deg_to_rad(-90.0), deg_to_rad(40.0))
