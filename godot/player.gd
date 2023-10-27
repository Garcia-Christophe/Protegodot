extends CharacterBody3D

# Signaux
signal maj_vie(valeur_vie) # Pour mettre à jour la vie du joueur remote
signal fin_de_partie() # Fin de partie quand un joueur a perdu

# Références aux noeuds de l'arbre
@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var flash_attack = $Corps/Flash
@onready var flash_defense = $Corps/FlashProtego
@onready var raycast = $Camera3D/RayCast3D

# Constantes
const SPEED = 8.0
const JUMP_VELOCITY = 10.0
const gravity = 20.0
var start_position
var start_rotation

# Variables
var vie = 5
var partie_en_cours = true

# Chaque joueur a une autorité différente, permettant d'avoir un contrôle séparé des personnages
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	
	# Définition de la position de départ
	if get_groups().has("gentil"):
		start_position = Vector3(0.856591, 0.033502, 33.2906)
		start_rotation = Vector3(0, 0.566814, 0)
	else:
		start_position = Vector3(-1.430012, 0.033501, -33.49818)
		start_rotation = Vector3(0, 3.14, 0)
	reset_position()

# Cycle de vie : appelé lorsque le noeud Harry entre dans l'arbre de scène pour la 1re fois
func _ready():
	if not is_multiplayer_authority(): return
	
	# Capturer la souris dans le jeu
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Associer la caméra courante au joueur
	camera.current = true

# Gestion de la souris
func _unhandled_input(event):
	if partie_en_cours:
		if not is_multiplayer_authority(): return
		
		# Déplacement (vue du joueur)
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * 0.005)
			camera.rotate_x(-event.relative.y * 0.005)
			camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		
		# Clic gauche (attaque)
		if Input.is_action_just_pressed("attack") and anim_player.current_animation != "Attaque":
			play_attack_effects.rpc()
			if raycast.is_colliding():
				var hit_player = raycast.get_collider()
				# Si ennemi = joueur (!= environnement) + si ennemi se défend pas
				if hit_player.has_method("is_protected") and not hit_player.is_protected():
					hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
		# Clic droit (défense)
		elif Input.is_action_just_pressed("defend"):
			play_defense_effects.rpc()

# Appelé à chaque frame ('delta' est le temps depuis la précédente frame)
func _physics_process(delta):
	if partie_en_cours:
		if not is_multiplayer_authority(): return

		# Si le joueur tombe dans l'eau, alors il perd une vie et respawn au milieu
		if position.y < -50 and is_on_floor():
			receive_damage()
		
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

# Jouer l'animation "Attente" à chaque fois que l'animation "Attaque" se termine
# C'est pour le joueur adverse remote (ex: je joue Harry, alors c'est pour Voldemort de MON écran)
func _on_animation_player_animation_finished(anim_name):
	if anim_name == "Attaque":
		anim_player.play("Attente")

# Replace le joueur à son spawn
func reset_position():
	position = start_position
	rotation = start_rotation

# Gestion de la fin de partie pour le joueur
@rpc("any_peer", "call_local")
func resultats(victoire):
#	queue_free()
	partie_en_cours = false
	print(get_groups())
	print("  victoire: ", victoire)

# Gestion de l'attaque
@rpc("call_local")
func play_attack_effects():
	# Animation de la baguette
	anim_player.stop()
	anim_player.play("Attaque")
	# Animation du flash
	flash_attack.restart()
	flash_attack.emitting = true
	# Affichage du sort
	if raycast.get_collider():
		MyUtils.creer_sort(flash_attack.global_transform.origin, raycast.get_collision_point(), flash_attack.draw_pass_1.material.albedo_color)

# Gestion de la défense
@rpc("call_local")
func play_defense_effects():
	# Animation de la baguette
	anim_player.stop()
	anim_player.play("Attaque")
	# Animation du flash
	flash_defense.restart()
	flash_defense.emitting = true

# Gestion de la réception de dégâts
@rpc("any_peer")
func receive_damage():
	vie -= 1
	reset_position()
	maj_vie.emit(vie) # Envoi du signal de mise à jour de la barre de vie
	if vie <= 0:
		fin_de_partie.emit() # Envoi du signal de fin de partie

# Information sur l'état de défense
@rpc("call_local")
func is_protected():
	return flash_defense.emitting