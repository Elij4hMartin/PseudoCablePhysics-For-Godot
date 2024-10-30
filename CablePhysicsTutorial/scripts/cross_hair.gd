extends TextureRect
# Used to change crosshair depending on what the player is doing
# HUD textures
@onready var hand_closed = preload("res://textures/placeholders/hand_closed.svg")
@onready var hand_open = preload("res://textures/placeholders/hand_open.svg")
@onready var hand_point = preload("res://textures/placeholders/hand_point.svg")
@onready var crosshair = preload("res://textures/placeholders/target_b.svg")

func _update_crosshair(state):
	match state:
		"closed":
			texture = hand_closed
		"open":
			texture = hand_open
		"point":
			texture = hand_point
		"crosshair":
			texture = crosshair
