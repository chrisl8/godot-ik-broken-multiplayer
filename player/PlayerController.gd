extends RigidBody2D

@export var player: int = -1
@export var player_spawn_point: Vector2 = Vector2(4, 1.5)

@export var SyncedPosition: Vector2 = Vector2(0, 0):
	set(new_value):
		SyncedPosition = new_value
		UpdateSyncedPosition = !IsLocal
var UpdateSyncedPosition: bool = false

@export var SyncedRotation: float = 0:
	set(new_value):
		SyncedRotation = new_value
		UpdateSyncedRotation = !IsLocal
var UpdateSyncedRotation: bool = false

@export var camera: Node

var InteractionController: Node2D

var IsLocal: bool = false
var WhiteSquare: Resource = preload("res://player/Debug Object.tscn")
var OtherMousePosition: Node2D
@export var MousePosition: Vector2
var ArmIKTarget: Node2D


func _ready() -> void:
	IsLocal = player == multiplayer.get_unique_id()

	set_physics_process(IsLocal)
	set_process_input(IsLocal)

	if IsLocal:
		camera.make_current()
		Globals.my_camera = camera
	else:
		camera.queue_free()
		gravity_scale = 0.0
		OtherMousePosition = WhiteSquare.instantiate()
		add_child(OtherMousePosition)


func _process(_delta: float) -> void:
	if !ArmIKTarget:
		ArmIKTarget = get_node_or_null("Left Hand Target")
	if IsLocal:
		MousePosition = get_global_mouse_position()
	else:
		OtherMousePosition.global_position = MousePosition
	ArmIKTarget.global_position = MousePosition


func _physics_process(delta: float) -> void:
	### Movement
	var MoveInput: Vector2 = relative_input()
	var Speed: float = 200.0

	var Velocity: Vector2 = linear_velocity
	if abs(MoveInput.x) > 0.1:
		Velocity = Vector2(MoveInput.x * Speed, Velocity.y)
	else:
		var Damp: float = 5000.0
		var Dampening: float = Velocity.x
		if Velocity.x < 0.0:
			Dampening = Velocity.x - (Damp * delta) * (Velocity.x / abs(Velocity.x))
			Dampening = clamp(Dampening, Velocity.x, 0.0)
		elif Velocity.x > 0:
			Dampening = Velocity.x - (Damp * delta) * (Velocity.x / abs(Velocity.x))
			Dampening = clamp(Dampening, 0.0, Velocity.x)

		Velocity = Vector2(Dampening, Velocity.y)
	if abs(MoveInput.y) > 0.1:
		Velocity = Vector2(Velocity.x, MoveInput.y * Speed)

	linear_velocity = Velocity
	SyncedPosition = position
	SyncedRotation = rotation


# Get movement vector based on input, relative to the player's head transform
func relative_input() -> Vector2:
	# Initialize the movement vector
	var move: Vector2 = Vector2()
	# Get cumulative input on axes
	var input: Vector3 = Vector3()
	input.z += int(Input.is_action_pressed("move_forward"))
	input.z -= int(Input.is_action_pressed("move_backward"))
	input.x += int(Input.is_action_pressed("move_right"))
	input.x -= int(Input.is_action_pressed("move_left"))
	# Add input vectors to movement relative to the direction the head is facing
	move.x = input.x
	move.y = -input.z
	# Normalize to prevent stronger diagonal forces
	return move.normalized()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if !IsLocal:
		if UpdateSyncedPosition and UpdateSyncedRotation:
			state.transform = Transform2D(SyncedRotation, SyncedPosition)
		elif UpdateSyncedPosition:
			state.transform = Transform2D(state.transform.get_rotation(), SyncedPosition)
		elif UpdateSyncedRotation:
			state.transform = Transform2D(SyncedRotation, state.origin)
		UpdateSyncedPosition = false
		UpdateSyncedRotation = false
