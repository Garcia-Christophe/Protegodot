extends CharacterBody3D

# Signaux
signal maj_vie(valeur_vie) # Pour mettre à jour la vie du joueur remote
signal maj_mana(mana) # Pour mettre à jour la mana du joueur remote
signal fin_de_partie() # Fin de partie quand un joueur a perdu
signal aller_au_menu_principal() # Réaffiche le menu principal
signal fermer_serveur() # Ferme le serveur

# Références aux noeuds de l'arbre
@onready var camera = $Camera3D
@onready var animation_joueur = $AnimationPlayer
@onready var flash_attaque = $Corps/Flash
@onready var flash_defense = $Corps/FlashProtego
@onready var raycast = $Camera3D/RayCast3D
@onready var menu_pause = $CanvasLayer/MenuPause
@onready var menu_fin = $CanvasLayer/MenuFin
@onready var titre_fin = $CanvasLayer/MenuFin/MarginContainer/VBoxContainer/Titre/Titre2
@onready var sort_son = $Son_Sort
@onready var protego_son = $Son_Protego
@onready var degats_son = $Son_Hit

# Constantes
const VITESSE = 8.0
const VELOCITE_SAUT = 10.0
const GRAVITE = 20.0
const NB_VIES = 100
const NB_MANA = 100
var position_depart
var rotation_depart
var camera_mini_map

# Variables
var vie = NB_VIES
var mana = NB_MANA
var partie_en_cours = true
var pause = false
var pause_recuperation_vie = false

# Chaque joueur a une autorité différente, permettant d'avoir un contrôle séparé des personnages
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	
	# Définition de la position de départ
	if get_groups().has("gentil"):
		position_depart = Vector3(0.856591, 0.033502, 33.2906)
		rotation_depart = Vector3(0, 0.566814, 0)
	else:
		position_depart = Vector3(-1.430012, 0.033501, -33.49818)
		rotation_depart = Vector3(0, 3.14, 0)
	reset_position()

# Cycle de vie : appelé lorsque le noeud Harry entre dans l'arbre de scène pour la 1re fois
func _ready():
	if not is_multiplayer_authority(): return
	
	# Définition de la caméra de la mini-map et de la couleur de son contour
	camera_mini_map = get_node("/root/Monde/CanvasLayer/VueJoueur/ColorRect/SubViewportContainer/SubViewport/CameraMiniMap")
	var contour_mini_map = get_node("/root/Monde/CanvasLayer/VueJoueur/ContourMiniMap")
	contour_mini_map.color = flash_attaque.draw_pass_1.material.albedo_color
	
	# Capturer la souris dans le jeu
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Associer les caméras courantes au joueur
	camera.current = true
	if camera_mini_map:
		camera_mini_map.current = true
	
	# Stockage des addresses IP si le joueur est l'hébergeur
	if get_groups().has("gentil"):
		var affichage_adresses_ip = $CanvasLayer/MenuPause/MarginContainer/VBoxContainer/HBoxContainer/Description2/TouchesDescription
		var liste_adresses_ip = get_node("../CanvasLayer/TransfertAddressesIP")
		if affichage_adresses_ip != null:
			affichage_adresses_ip.text = liste_adresses_ip.text
		# Enlève l'adversaire de la mini map du joueur
		camera_mini_map.set_cull_mask_value(7, false)
		camera_mini_map.set_cull_mask_value(8, false)
	else:
		# Enlève l'adversaire de la mini map du joueur
		camera_mini_map.set_cull_mask_value(1, false)
		camera_mini_map.set_cull_mask_value(9, false)

# Gestion de la souris
func _unhandled_input(event):
	if partie_en_cours:
		if not is_multiplayer_authority(): return
		
		# Touche Echap : affiche le menu pause
		if Input.is_action_just_pressed("echap"):
			pause = true
			menu_pause.show()
			# Ne plus capturer la souris
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		if !pause:
			# Déplacement (vue du joueur)
			if event is InputEventMouseMotion:
				rotate_y(-event.relative.x * 0.003)
				camera.rotate_x(-event.relative.y * 0.003)
				camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
			
			# Clic gauche (attaque)
			if Input.is_action_just_pressed("attaquer") and animation_joueur.current_animation != "Attaque":
				effets_attaque.rpc()
				if raycast.is_colliding():
					var collider = raycast.get_collider()
					if collider.is_in_group("aiguilleMinute"):
						restaurer_vie.rpc()
					# Si ennemi = joueur (!= environnement) + si ennemi se défend pas
					elif collider.has_method("est_protege") and not collider.est_protege():
						collider.reception_degats.rpc_id(collider.get_multiplayer_authority(), position)
			# Clic droit (défense)
			elif Input.is_action_just_pressed("defendre") and animation_joueur.current_animation != "Attaque" and mana == NB_MANA:
				effets_defense.rpc()

# Appelé à chaque frame ('delta' est le temps depuis la précédente frame)
func _physics_process(delta):
	if partie_en_cours:
		if multiplayer.multiplayer_peer and !is_multiplayer_authority(): return
		
		# La caméra de la mini map doit suivre le joueur
		if camera_mini_map:
			camera_mini_map.position = Vector3(position.x, 30, position.z)
	
		# Si le joueur tombe dans l'eau (ou hors de la map), alors il perd une vie et respawn au milieu
		if (position.y < -50 and is_on_floor()) or position.y < -60:
			reception_degats(Vector3(position.x - 25, position.y, position.z))
		
		# Si le joueur saute depuis un pilier de l'entrée du château, gagne 1 vie
		if position.y > 12 and position.z < 15 and !pause_recuperation_vie:
			soigner.rpc()
		elif position.y < 12:
			pause_recuperation_vie = false
		
		# Gestion de la gravité
		if not is_on_floor():
			velocity.y -= GRAVITE * delta

		if !pause:
			# Gestion du saut
			if Input.is_action_just_pressed("sauter") and is_on_floor():
				velocity.y = VELOCITE_SAUT

			# Gestion des déplacements
			var input_direction = Input.get_vector("aller_gauche", "aller_droite", "avancer", "reculer")
			var direction = (transform.basis * Vector3(input_direction.x, 0, input_direction.y))
			if direction:
				velocity.x = direction.x * VITESSE
				velocity.z = direction.z * VITESSE
			else:
				velocity.x = move_toward(velocity.x, 0, VITESSE)
				velocity.z = move_toward(velocity.z, 0, VITESSE)
			
			# Gestion des animations Marche/Attente
			if animation_joueur.current_animation == "Attaque":
				pass
			elif input_direction != Vector2.ZERO and is_on_floor():
				animation_joueur.play("Marche")
			else:
				animation_joueur.play("Attente")
			
			# Gestion de la mana (pour pouvoir se défendre)
			if mana < NB_MANA:
				mana += 1
				maj_mana.emit(mana)

		move_and_slide()

# Bouton Reprendre la partie
func _on_reprendre_btn_pressed():
	pause = false
	menu_pause.hide()
	# Capture de la souris dans le jeu à nouveau
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Bouton Quitter la partie
@rpc("any_peer", "call_local")
func _on_quitter_btn_pressed():
	if get_groups().has("gentil"):
		fermer_serveur.emit()
	partie_en_cours = false
	pause = false
	menu_pause.hide()
	aller_au_menu_principal.emit(name)
	# Ne plus capturer la souris
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	multiplayer.multiplayer_peer = null

# Bouton Rejouer une partie
func _on_rejouer_btn_pressed():
	# Capture de la souris dans le jeu à nouveau
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Reset la partie
	partie_en_cours = true
	pause = false
	menu_fin.hide()
	# Reset le personnage
	reset_position()
	mana = NB_MANA
	vie = NB_VIES
	maj_vie.emit(vie)

# Jouer l'animation "Attente" à chaque fois que l'animation "Attaque" se termine
# C'est pour le joueur adverse remote (ex: je joue Harry, alors c'est pour Voldemort de MON écran)
func _on_animation_player_animation_finished(nom_animation):
	if nom_animation == "Attaque":
		animation_joueur.play("Attente")

# Replace le joueur à son spawn
func reset_position():
	position = position_depart
	rotation = rotation_depart

# Gestion de la fin de partie pour le joueur
@rpc("any_peer", "call_local")
func resultats():
	partie_en_cours = false
	menu_fin.show()
	# Ne plus capturer la souris
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if vie > 0:
		titre_fin.text = "GAGNÉ !"
	else:
		titre_fin.text = "PERDU !"

# Gestion de l'attaque
@rpc("call_local")
func effets_attaque():
	# Son du sort
	sort_son.stop()
	protego_son.stop()
	sort_son.play()
	# Animation de la baguette
	animation_joueur.stop()
	animation_joueur.play("Attaque")
	# Animation du flash
	flash_attaque.restart()
	flash_attaque.emitting = true
	# Affichage du sort
	if raycast.get_collider():
		Outils.creer_sort(flash_attaque.global_transform.origin, raycast.get_collision_point(), flash_attaque.draw_pass_1.material.albedo_color)

# Gestion de la défense
@rpc("call_local")
func effets_defense():
	# Reset de la mana
	mana = 0
	maj_mana.emit(mana)
	# Son du sort
	sort_son.stop()
	protego_son.stop()
	protego_son.play()
	# Animation de la baguette
	animation_joueur.stop()
	animation_joueur.play("Attaque")
	# Animation du flash
	flash_defense.restart()
	flash_defense.emitting = true

# Restaure entièrement la vie du joueur
@rpc("call_local")
func restaurer_vie():
	# Mise à jour de la vie
	vie = NB_VIES
	maj_vie.emit(vie) # Envoi du signal de mise à jour de la barre de vie
	# Animation du flash de défense
	flash_defense.restart()
	flash_defense.emitting = true

# Restaure légèrement la vie du joueur (si blessé)
@rpc("call_local")
func soigner():
	if vie < NB_VIES:
		# Mise à jour de la vie
		vie += 20
		maj_vie.emit(vie) # Envoi du signal de mise à jour de la barre de vie
		pause_recuperation_vie = true
		# Animation du flash de défense
		flash_defense.restart()
		flash_defense.emitting = true

# Gestion de la réception de dégâts
@rpc("any_peer")
func reception_degats(position_ennemi):
	# Son du sort
	sort_son.stop()
	protego_son.stop()
	degats_son.play()
	# Distance entre l'ennemi et le joueur actuel
	var distance = position_ennemi.distance_to(position)
	# Je ne veux pas me fâcher avec les maths...
	if distance <= 0:
		distance = 1
	# Calcul des dégâts proportionnellement à la distance (plus loin = moins mal)
	var degats = int(round(35 - 0.6 * distance))
	if degats <= 2:
		degats = 3
	# Mise à jour de la vie et de la position
	vie -= degats
	if vie < 0:
		vie = 0
	reset_position()
	maj_vie.emit(vie) # Envoi du signal de mise à jour de la barre de vie
	if vie <= 0:
		fin_de_partie.emit() # Envoi du signal de fin de partie

# Information sur l'état de défense
@rpc("call_local")
func est_protege():
	return flash_defense.emitting
