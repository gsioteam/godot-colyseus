extends Node2D

const colyseus = preload("res://addons/godot_colyseus/lib/colyseus.gd")
const Char = preload("./char.tscn")

class Player extends colyseus.Schema:
	static func define_fields():
		return [
			colyseus.Field.new("x", colyseus.NUMBER),
			colyseus.Field.new("y", colyseus.NUMBER)
		]
	
	var node
	
	func _to_string():
		return str("(",self.x,",",self.y,")")

class RoomState extends colyseus.Schema:
	static func define_fields():
		return [
			colyseus.Field.new("players", colyseus.MAP, Player),
		]

var room: colyseus.Room

# Called when the node enters the scene tree for the first time.
func _ready():
	var client = colyseus.Client.new("ws://localhost:2567")
	var promise = client.join_or_create(RoomState, "state_handler")
	await promise.completed
	if promise.get_state() == promise.State.Failed:
		print("Failed")
		return
	var room: colyseus.Room = promise.get_data()
	var state: RoomState = room.get_state()
	state.listen('players:add').on(Callable(self, "_on_players_add"))
	room.on_state_change.on(Callable(self, "_on_state"))
	room.on_message("hello").on(Callable(self, "_on_message"))
	self.room = room
	
func _on_message(data):
	print(str("hello:", data))

func _on_state(state):
	pass

func _on_players_add(target, value, key):
	print("Add:", " key:", key, " ", value)
	var ch = Char.instantiate()
	ch.position = Vector2(value.x, value.y)
	add_child(ch)
	value.node = ch
	value.listen(":change").on(Callable(self, "_on_player"))

func _on_player(target):
	print("Change ", target)
	var ch = target.node
	ch.position = Vector2(target.x, target.y)

func _physics_process(delta):
	if Input.is_action_pressed("ui_up"):
		room.send("move", { y = -1 });
	elif Input.is_action_pressed("ui_down"):
		room.send("move", { y = 1 });
	elif Input.is_action_pressed("ui_left"):
		room.send("move", { x = -1 });
	elif Input.is_action_pressed("ui_right"):
		room.send("move", { x = 1 });
