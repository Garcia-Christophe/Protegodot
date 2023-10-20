extends Node

# Références aux noeuds de l'arbre
@onready var menu_principal = $CanvasLayer/MenuPrincipal
@onready var input_adresse = $CanvasLayer/MenuPrincipal/MarginContainer/VBoxContainer/Rejoindre/InputAdresse
@onready var vue_joueur = $CanvasLayer/VueJoueur
@onready var barre_de_vie = $CanvasLayer/VueJoueur/BarreDeVie

# Constantes
const HARRY = preload("res://harry.tscn")
const VOLDY = preload("res://voldy.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

# Quitter la partie
func _unhandled_input(_event):
	# Touche Echap
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

# Gestion du bouton "Héberger"
func _on_heberger_btn_pressed():
	# Switch de panel
	menu_principal.hide()
	vue_joueur.show()
	
	# Création du serveur
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_voldy)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_harry(multiplayer.get_unique_id())

# Gestion du bouton "Rejoindre"
func _on_rejoindre_btn_pressed():
	# Switch de panel
	menu_principal.hide()
	vue_joueur.show()
	
	# Création du client
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer

# Ajout de Harry dans l'arbre
func add_harry(peer_id):
	var harry = HARRY.instantiate()
	harry.name = str(peer_id)
	add_child(harry)
	if harry.is_multiplayer_authority():
		harry.maj_vie.connect(maj_barre_de_vie)

# Ajout de Voldemort dans l'arbre
func add_voldy(peer_id):
	var voldy = VOLDY.instantiate()
	voldy.name = str(peer_id)
	add_child(voldy)
	if voldy.is_multiplayer_authority():
		voldy.maj_vie.connect(maj_barre_de_vie)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func maj_barre_de_vie(valeur_vie):
	barre_de_vie.value = valeur_vie

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.maj_vie.connect(maj_barre_de_vie)
