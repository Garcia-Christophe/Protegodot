extends CharacterBody3D

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var flash = $Corps/Flash

const SPEED = 8.0
const JUMP_VELOCITY = 10.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

func _ready():
	# Capturer la souris dans le jeu
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Gestion de la souris (vue du joueur)
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if Input.is_action_just_pressed("attack") and anim_player.current_animation != "Attaque":
		play_attack_effects()

func _physics_process(delta):
	# Gestion de la gravité
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Gestion du saut
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Gestion des déplacements
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	# Gestion des animations Marche/Attente
	if anim_player.current_animation == "Attaque":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("Marche")
	else:
		anim_player.play("Attente")

	move_and_slide()

func play_attack_effects():
	anim_player.stop()
	anim_player.play("Attaque")
	flash.restart()
	flash.emitting = true
