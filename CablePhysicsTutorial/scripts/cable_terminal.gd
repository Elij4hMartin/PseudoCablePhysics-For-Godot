extends Area3D

var current_node
# only true when terminal ID = key item ID
@export var terminal_ID = 1
var state = false
@onready var player = get_tree().get_first_node_in_group("Player")
var prev_node = null

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Cable") and current_node == null:
		player._drop_or_throw_item(false)
		current_node = body
		lock_body()

func lock_body():
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(current_node, "global_position", $Node3D.global_position, 0.2)
	tween.tween_property(current_node, "global_rotation", $Node3D.global_rotation, 0.2)
	current_node.sleeping = true
	current_node.freeze = true
	
	# check if key item ID matches terminal ID
	#if current_node.get_parent().key_ID == terminal_ID:
		#print("cable match!")
		#state = true
	#else:
		#print("cable doesn't match!")
		#state = false

func _on_body_exited(body: Node3D) -> void:
	if body == current_node and player.holding_object:
		current_node = null
		state = false
