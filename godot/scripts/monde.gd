extends Node

# Références aux noeuds de l'arbre
@onready var menu_principal = $CanvasLayer/MenuPrincipal
@onready var input_adresse = $CanvasLayer/MenuPrincipal/MarginContainer/VBoxContainer/Rejoindre/InputAdresse
@onready var vue_joueur = $CanvasLayer/VueJoueur
@onready var barre_de_vie = $CanvasLayer/VueJoueur/BarreDeVie
@onready var barre_de_mana = $CanvasLayer/VueJoueur/BarreDeMana
@onready var nb_vies = $CanvasLayer/VueJoueur/BarreDeVie/nbVies
@onready var nb_mana = $CanvasLayer/VueJoueur/BarreDeMana/nbMana

# Constantes
const HARRY = preload("res://scenes/harry.tscn")
const VOLDY = preload("res://scenes/voldy.tscn")
const PORT = 9999
const MAX_CLIENTS = 2
var partie_commencee = false
var enet_peer = ENetMultiplayerPeer.new()

func _physics_process(_delta):
	# Fermeture du serveur lorsque plus personne n'est dessus
	if partie_commencee and get_tree().get_nodes_in_group("joueur").size() == 0:
		if multiplayer.is_connected("peer_connected", add_player):
			multiplayer.peer_connected.disconnect(add_player)
		if multiplayer.is_connected("peer_disconnected", remove_player):
			multiplayer.peer_disconnected.disconnect(remove_player)

# Gestion du bouton "Héberger"
func _on_heberger_btn_pressed():
	# Switch de panel
	menu_principal.hide()
	vue_joueur.show()
	
	# Création du serveur
	if enet_peer.get_connection_status() != 0:
		multiplayer.multiplayer_peer = null
		enet_peer.close()
	enet_peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	multiplayer.multiplayer_peer = enet_peer
	
	# Setup du multijoueurs
	print("\nTentative d'établissement du multijoueur...")
	if !upnp_setup():
		print("Tes conditions ne permettent pas de host une game en ligne.")
	display_ip_addresses()
	
	# Ajoute le 1re joueur (car le serveur est créé par le pc d'un joueur)
	add_player(multiplayer.get_unique_id())

# Gestion du bouton "Rejoindre"
func _on_rejoindre_btn_pressed():
	# Switch de panel
	menu_principal.hide()
	vue_joueur.show()
	
	# Création du client
	if input_adresse.text == "":
		input_adresse.text = "localhost"
	if enet_peer.get_connection_status() != 0:
		multiplayer.multiplayer_peer = null
		enet_peer.close()
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
		player.maj_mana.connect(maj_barre_de_mana)
		player.fin_de_partie.connect(resultats)
		player.goto_menu_principal.connect(show_menu_principal)
		player.fermer_serveur.connect(fermer_serveur)
		partie_commencee = true

# Suppression du joueur client dans l'arbre (ici Voldemort)
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

# Synchronisation de la barre de vie
func maj_barre_de_vie(valeur_vie):
	barre_de_vie.value = valeur_vie
	nb_vies.text = str(valeur_vie)

# Synchronisation de la barre de mana
func maj_barre_de_mana(mana):
	barre_de_mana.value = mana
	nb_mana.text = str(mana)

# Fin de partie
func resultats():
	var joueurs = get_tree().get_nodes_in_group("joueur")
	for joueur in joueurs:
		joueur.resultats.rpc_id(joueur.get_multiplayer_authority())

# Affiche le menu principal
func show_menu_principal(peer_id):
	menu_principal.show()
	vue_joueur.hide()
	
	# Retire tous les joueurs de l'arbre global de chaque joueur
	remove_player(peer_id)
	for joueur in multiplayer.get_peers():
		remove_player(joueur)

# Ferme le serveur
func fermer_serveur():
	# Déconnecte les clients
	var joueurs = get_tree().get_nodes_in_group("mechant")
	for joueur in joueurs:
		joueur._on_quitter_btn_pressed.rpc_id(joueur.get_multiplayer_authority())

# Dès qu'un joueur spawn, le connecte à sa barre de vie et aux résultats
func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.maj_vie.connect(maj_barre_de_vie)
		node.maj_mana.connect(maj_barre_de_mana)
		node.fin_de_partie.connect(resultats)
		node.goto_menu_principal.connect(show_menu_principal)
		node.fermer_serveur.connect(fermer_serveur)

# Mise en place du multijoueurs
func upnp_setup():
	var upnp = UPNP.new()
	
	# Vérifie que UPNP existe (si c'est activé)
	var discover_result = upnp.discover()
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		print("  Multijoueur KO :(\n  Erreur : 'UPNP Discover' > %s" % discover_result)
		return false
	
	# Vérifie si UPNP peut être utilisé correctement
	if !(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway()):
		print("  Multijoueur KO :(\n  Erreur : 'UPNP Gateway' > gateway invalide")
		return false
	
	# Fait le lien avec le port du jeu
	var map_result = upnp.add_port_mapping(PORT)
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		print("  Multijoueur KO :(\n  Erreur : 'UPNP Port Mapping' > %s" % map_result)
		return false
	
	# Succès :)
	print("  Multijoueurs OK :)\n  Adresse en ligne : %s" % upnp.query_external_address())
	var ip_addresses = $CanvasLayer/TransfertAddressesIP
	ip_addresses.text = "Adresse en ligne :\n   -> %s" % upnp.query_external_address()
	return true

# Enregistrement des adresses locales du PC host pour pouvoir jouer en LAN
func display_ip_addresses():
	var ip_addresses = $CanvasLayer/TransfertAddressesIP
	ip_addresses.text += "\nAdresses locales :"
	for ip in IP.get_local_addresses():
		if "." in ip:
			ip_addresses.text += "\n   - " + ip
	