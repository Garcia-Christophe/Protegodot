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
		if multiplayer.is_connected("peer_connected", ajouter_joueur):
			multiplayer.peer_connected.disconnect(ajouter_joueur)
		if multiplayer.is_connected("peer_disconnected", supprimer_joueur):
			multiplayer.peer_disconnected.disconnect(supprimer_joueur)

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
	multiplayer.peer_connected.connect(ajouter_joueur)
	multiplayer.peer_disconnected.connect(supprimer_joueur)
	multiplayer.multiplayer_peer = enet_peer
	
	# Setup du multijoueurs
	var addresses_ip = $CanvasLayer/TransfertAddressesIP
	if !upnp_setup(addresses_ip):
		addresses_ip.text = "Multijoueurs KO :(\n" + addresses_ip.text + "\n"
	else:
		addresses_ip.text = "Multijoueurs OK :)\n" + addresses_ip.text + "\n"
	display_ip_addresses(addresses_ip)
	
	# Ajoute le 1re joueur (car le serveur est créé par le pc d'un joueur)
	ajouter_joueur(multiplayer.get_unique_id())

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
func ajouter_joueur(peer_id):
	var joueur
	if get_tree().get_nodes_in_group("joueur").size() > 0:
		joueur = VOLDY.instantiate()
	else:
		joueur = HARRY.instantiate()
	joueur.name = str(peer_id)
	add_child(joueur)
	if joueur.is_multiplayer_authority():
		joueur.maj_vie.connect(maj_barre_de_vie)
		joueur.maj_mana.connect(maj_barre_de_mana)
		joueur.fin_de_partie.connect(resultats)
		joueur.aller_au_menu_principal.connect(afficher_menu_principal)
		joueur.fermer_serveur.connect(fermer_serveur)
		partie_commencee = true

# Suppression du joueur client dans l'arbre (ici Voldemort)
func supprimer_joueur(peer_id):
	var joueur = get_node_or_null(str(peer_id))
	if joueur:
		joueur.queue_free()

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
func afficher_menu_principal(peer_id):
	menu_principal.show()
	vue_joueur.hide()
	
	# Retire tous les joueurs de l'arbre global de chaque joueur
	supprimer_joueur(peer_id)
	for joueur in multiplayer.get_peers():
		supprimer_joueur(joueur)

# Ferme le serveur
func fermer_serveur():
	# Déconnecte les clients
	var joueurs = get_tree().get_nodes_in_group("mechant")
	for joueur in joueurs:
		joueur._on_quitter_btn_pressed.rpc_id(joueur.get_multiplayer_authority())

# Dès qu'un joueur spawn, le connecte aux différents signaux
func _on_multiplayer_spawner_spawned(joueur):
	if joueur.is_multiplayer_authority():
		joueur.maj_vie.connect(maj_barre_de_vie)
		joueur.maj_mana.connect(maj_barre_de_mana)
		joueur.fin_de_partie.connect(resultats)
		joueur.aller_au_menu_principal.connect(afficher_menu_principal)
		joueur.fermer_serveur.connect(fermer_serveur)

# Mise en place du multijoueur
func upnp_setup(addresses_ip):
	var upnp = UPNP.new()
	
	# Vérifie que UPNP existe (si c'est activé)
	var resultat_discover = upnp.discover()
	if resultat_discover != UPNP.UPNP_RESULT_SUCCESS:
		print("Multijoueur Erreur : 'UPNP Discover' > %s" % resultat_discover)
		return false
	
	# Vérifie si UPNP peut être utilisé correctement
	if !(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway()):
		print("Multijoueur Erreur : 'UPNP Gateway' > gateway invalide")
		return false
	
	# Fait le lien avec le port du jeu
	var resultat_mapping = upnp.add_port_mapping(PORT)
	if resultat_mapping != UPNP.UPNP_RESULT_SUCCESS:
		print("Multijoueur Erreur : 'UPNP Port Mapping' > %s" % resultat_mapping)
		return false
	
	# Succès :)
	addresses_ip.text = "Adresse en ligne :\n   - %s" % upnp.query_external_address()
	return true

# Enregistrement des adresses locales du PC host pour pouvoir jouer en LAN
func display_ip_addresses(addresses_ip):
	addresses_ip.text += "\nAdresses locales :"
	for ip in IP.get_local_addresses():
		if "." in ip:
			addresses_ip.text += "\n   - " + ip
	
