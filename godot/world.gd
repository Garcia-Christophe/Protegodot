extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

# Quitter la partie
func _unhandled_input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()