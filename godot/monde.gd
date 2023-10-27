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
	enet_peer.create_server(PORT, 1) # 2e param = max clients
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	# Affichage des adresses locales du PC host pour pouvoir jouer en LAN
	print("Pour jouer en LAN :")
	for ip in IP.get_local_addresses():
		print("  - ", ip)
	
	# Setup du multijoueurs
	print("\nTentative d'établissement du multijoueurs...")
	upnp_setup()
	
	# Ajoute le 1re joueur (car le serveur est créé par le pc d'un joueur)
	add_player(multiplayer.get_unique_id())
#	enet_peer.create_client("localhost", PORT)
#	multiplayer.multiplayer_peer = enet_peer

# Gestion du bouton "Rejoindre"
func _on_rejoindre_btn_pressed():
	# Switch de panel
	menu_principal.hide()
	vue_joueur.show()
	
	# Création du client
	if input_adresse.text == "":
		input_adresse.text = "localhost"
	enet_peer.create_client(input_adresse.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

# Ajout du joueur dans l'arbre
func add_player(peer_id):
	var player
	if get_tree().get_nodes_in_group("joueur").size() > 0:
		player = VOLDY.instantiate()
	else:
		player = HARRY.instantiate()
	player.name = str(peer_id)
	add_child(player)
	if player.is_multiplayer_authority():
		player.maj_vie.connect(maj_barre_de_vie)
		player.fin_de_partie.connect(resultats)

# Suppression du joueur dans l'arbre
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

# Synchronisation de la barre de vie
func maj_barre_de_vie(valeur_vie):
	barre_de_vie.value = valeur_vie

# Fin de partie
func resultats():
	var joueurs = get_tree().get_nodes_in_group("joueur")
	print(" * joueurs.size(): ", joueurs.size())
	for joueur in joueurs:
		joueur.resultats.rpc(joueur.vie > 0)

# Dès qu'un joueur spawn, le connecte à sa barre de vie et aux résultats
func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.maj_vie.connect(maj_barre_de_vie)
		node.fin_de_partie.connect(resultats)

# Mise en place du multijoueurs
func upnp_setup():
	var upnp = UPNP.new()
	
	# Vérifie que UPNP existe (si c'est activé)
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "\nMultijoueur KO :(\nErreur : 'UPNP Discover' > %s" % discover_result)
	
	# Vérifie si UPNP peut être utilisé correctement
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "\nMultijoueur KO :(\nErreur : 'UPNP Gateway' > gateway invalide")
	
	# Fait le lien avec le port du jeu
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "\nMultijoueur KO :(\nErreur : 'UPNP Port Mapping' > %s" % map_result)
	
	# Succès :)
	print("Multijoueurs OK :)\nAdresse en ligne : %s" % upnp.query_external_address())
