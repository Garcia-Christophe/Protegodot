extends Node

# Références aux noeuds de l'arbre
@onready var menu_principal = $CanvasLayer/MenuPrincipal
@onready var input_adresse = $CanvasLayer/MenuPrincipal/MarginContainer/VBoxContainer/Rejoindre/InputAdresse

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
	menu_principal.hide()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_voldy)
	
	add_harry(multiplayer.get_unique_id())

# Gestion du bouton "Rejoindre"
func _on_rejoindre_btn_pressed():
	menu_principal.hide()
	
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer

# Ajout de Harry dans l'arbre
func add_harry(peer_id):
	print("harry: ", peer_id)
	var harry = HARRY.instantiate()
	harry.name = str(peer_id)
	add_child(harry)

# Ajout de Voldemort dans l'arbre
func add_voldy(peer_id):
	print("voldy: ", peer_id)
	var voldy = VOLDY.instantiate()
	voldy.name = str(peer_id)
	add_child(voldy)
