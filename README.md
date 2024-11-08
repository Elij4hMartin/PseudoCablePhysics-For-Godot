# PsuedoCablePhysics-For-Godot
This is a simple approximation of rope/cable physics for Godot 4.3 that I made for a Screamjam submission, because I couldn't find a Verlet simulation that worked with the version of Godot I was using.
Download this project and open it in Godot 4.3 to test out the project!
### CC0 Assets used: Kenney UI Pack, Kenney Prototype Textures
### Video DEMO
[![VIDEO DEMO](https://img.youtube.com/vi/K8SLWUsPFNY/0.jpg)](https://www.youtube.com/watch?v=K8SLWUsPFNY)
## Script usage instructions:
- Attach the pseudo_physics_cable.gd script to a Node3D
- Make sure you have the mesh_instance_3d.tscn scene in a "scenes" folder or change the script path to the file for the cable_mesh variable
- Add a start point as either a static node or a rigidbody
- Add a end point that is either a static node or a rigidbody
- If an end/start point is a rigidbody enable the exported variable for each end
- Lastly adjust the values of the cable length, gravity and springiness to your desired values
## Here is the script that is responsible for the basic simulation:
```GDscript
extends Node3D

@export var start_point : Node3D
@export var start_is_rigidbody = false
@export var end_point : Node3D
@export var end_is_rigidbody = true
@export_range(1,50,1) var number_of_segments = 10
@export_range(0, 100.0, 0.1) var cable_length = 5.0
@export var cable_gravity_amp = 0.245
@export var cable_thickness = 0.1
@export var cable_springiness = 9.81*2
@onready var cable_mesh := preload("res://scenes/mesh_instance_3d.tscn")
@onready var segment_stretch = float(cable_length/number_of_segments)
# instances
var segments : Array
var joints : Array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var distance = (end_point.global_position - start_point.global_position).length()
	var direction = (end_point.global_position - start_point.global_position).normalized()
	# start at start point
	joints.append(start_point)
	# create joints
	for j in (number_of_segments - 1):
		joints.append(Node3D.new())
		self.add_child(joints[j+1])
		# position nodes evenly between the two points
		joints[j+1].global_position = start_point.global_position + direction * (j + 1) * distance / (number_of_segments - 1)
	# end at end point
	joints.append(end_point)
	# create cable segments
	for s in number_of_segments:
		segments.append(cable_mesh.instantiate())
		self.add_child(segments[s])
		# position segments between the joints
		segments[s].global_position = joints[s].global_position + (joints[s+1].global_position - joints[s].global_position)/2
		segments[s].get_child(0).mesh.top_radius = cable_thickness/2.0
		segments[s].get_child(0).mesh.bottom_radius = cable_thickness/2.0

func _process(_delta: float) -> void:
	# Make segments point at their target and stretch/squash to their desired length
	for i in number_of_segments:
		# set position between joints
		segments[i].global_position = joints[i].global_position + (joints[i+1].global_position - joints[i].global_position)/2
		# look at next joint
		safe_look_at(segments[i], joints[i+1].global_position + Vector3(0.0001, 0, -0.0001))
		# set length to the distance between the joints
		segments[i].get_child(0).mesh.height = (joints[i+1].global_position - joints[i].global_position).length()

func _physics_process(delta: float) -> void:
	# fake physics
	for i in number_of_segments:
		if i != 0:
			# collision
			var query = PhysicsRayQueryParameters3D.create(joints[i].global_position, joints[i].global_position - Vector3(0,cable_thickness, 0))
			var raycast = get_world_3d().direct_space_state.intersect_ray(query)
			# Gravity
			if raycast.get("collider") == null:
				joints[i].global_position.y = lerp(joints[i].global_position.y, joints[i].global_position.y - 1, cable_gravity_amp * delta/2.0)
			# stretch
			joints[i].global_position = lerp(joints[i].global_position, joints[i-1].global_position + (joints[i+1].global_position - joints[i-1].global_position)/2.0, cable_springiness * delta)
	# Retract
	if end_is_rigidbody:
		if (end_point.global_position - joints[0].global_position).length() >= segment_stretch * number_of_segments:
			var modifier = (end_point.global_position - joints[0].global_position).length() - segment_stretch * number_of_segments
			modifier = clamp(modifier, 0.0, cable_springiness)
			end_point.linear_velocity -= (end_point.global_position - joints[-2].global_position)*modifier
	if start_is_rigidbody:
		if (end_point.global_position - joints[0].global_position).length() >= segment_stretch * number_of_segments:
			var modifier = (end_point.global_position - joints[0].global_position).length() - segment_stretch * number_of_segments
			modifier = clamp(modifier, 0.0, cable_springiness)
			joints[0].linear_velocity -= (joints[0].global_position - joints[1].global_position)*modifier

func safe_look_at(node : Node3D, target : Vector3) -> void:
	var origin : Vector3 = node.global_transform.origin
	var v_z := (origin - target).normalized()

	# Just return if at same position
	if origin == target:
		return

	# Find an up vector that we can rotate around
	var up := Vector3.ZERO
	for entry in [Vector3.UP, Vector3.RIGHT, Vector3.BACK]:
		var v_x : Vector3 = entry.cross(v_z).normalized()
		if v_x.length() != 0:
			up = entry
			break

	# Look at the target
	if up != Vector3.ZERO:
		node.look_at(target, up)

```
