extends Node

# Création du sort (affichage temporaire)
func creer_sort(pos1: Vector3, pos2: Vector3, color):
	var mesh_instance := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	var material := ORMMaterial3D.new()
	
	# Définition du mesh Instance3D
	mesh_instance.mesh = immediate_mesh
	mesh_instance.set_layer_mask_value(5, true)
	
	# Définition du mesh Immediate
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(pos1)
	immediate_mesh.surface_add_vertex(pos2)
	immediate_mesh.surface_end()
	
	# Définition de la matière du sort
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	
	# Apparition du sort dans l'arbre principal
	get_tree().get_root().add_child(mesh_instance)
	# Disparition du sort au bout de 0.25s
	get_tree().create_timer(0.25).timeout.connect(func():mesh_instance.queue_free())
