extends Reference

const Promise = preload("res://addons/godot_colyseus/lib/promises.gd").Promise;
const RunPromise = preload("res://addons/godot_colyseus/lib/promises.gd").RunPromise;
const HTTP = preload("res://addons/godot_colyseus/lib/http.gd")
const CRoom = preload("res://addons/godot_colyseus/lib/room.gd")
const RoomInfo = preload("res://addons/godot_colyseus/lib/room_info.gd")

var endpoint: String

func _init(endpoint: String):
	self.endpoint = endpoint

func join_or_create(schema_type: GDScript, room_name: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		funcref(self, "_create_match_make_request"), 
		["joinOrCreate", room_name, options, schema_type])

func create(schema_type: GDScript, room_name: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		funcref(self, "_create_match_make_request"), 
		["create", room_name, options, schema_type])

func join(schema_type: GDScript, room_name: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		funcref(self, "_create_match_make_request"), 
		["join", room_name, options, schema_type])

func join_by_id(schema_type: GDScript, room_id: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		funcref(self, "_create_match_make_request"), 
		["joinById", room_id, options, schema_type])

func reconnect(schema_type: GDScript, room_id: String, session_id: String) -> Promise:
	return RunPromise.new(
		funcref(self, "_create_match_make_request"), 
		["joinById", room_id, {"sessionId": session_id}, schema_type])

func get_available_rooms(room_name:String) -> Promise:
	var path = "/matchmake/" + room_name
	return RunPromise.new(
		funcref(self, "_http_get"),
		[path, {"Accept": "application/json"}]
	).then(funcref(self, "_process_rooms"))

func _create_match_make_request(
	promise: Promise, 
	method: String, 
	room_name: String, 
	options: Dictionary,
	schema_type: GDScript):
	var path: String = "/matchmake/" + method + "/" + room_name
	var server = endpoint
	if server.begins_with("ws"):
		server = server.replace("ws", "http")
	if options == null:
		options = {}
	var http = HTTP.new(server)
	var req = HTTP.RequestInfo.new("POST", path)
	req.add_header("Accept", "application/json")
	req.add_header("Content-Type", "application/json")
	req.body = options
	var resp = http.fetch(req)
	
	if resp.get_state() == Promise.State.Waiting:
		yield(resp, "completed")
	if resp.get_state() == Promise.State.Failed:
		promise.reject(resp.get_error())
		return
	var res: HTTP.Response = resp.get_result()
	var response = res.json()
	
	if response.get('code') != null:
		promise.reject(response['error'])
		return
	var room = CRoom.new(response["room"]["name"], schema_type)
	room.room_id = response["room"]["roomId"]
	room.session_id = response["sessionId"]
	
	room.connect_remote(_build_endpoint(response["room"], { "sessionId": room.session_id }))
	
	room.on_join.once(funcref(self, "_room_joined"), [promise, room])
	room.on_error.once(funcref(self, "_room_error"), [promise, room])

func _room_joined(promise: Promise, room: CRoom):
	room.on_error.off(funcref(self, "_room_error"))
	promise.resolve(room)

func _room_error(code: int, message: String, promise: Promise, room: CRoom):
	promise.reject(str("[", code, "]", message))

func _build_endpoint(room: Dictionary, options: Dictionary = {}):
	var params = PoolStringArray()
	for name in options.keys():
		params.append(name + "=" + options[name])
	return endpoint + "/" + room["processId"] + "/" + room["roomId"] + "?" + params.join("&")

func _http_get(promise: Promise, path: String, headers: Dictionary):
	var server = endpoint
	if server.begins_with("ws"):
		server = server.replace("ws", "http")
	var http = HTTP.new(server)
	var req = HTTP.RequestInfo.new("GET", path)
	for key in headers.keys():
		req.add_header(key, headers[key])
	var resp = http.fetch(req)
	
	if resp.get_state() == Promise.State.Waiting:
		yield(resp, "completed")
	if resp.get_state() == Promise.State.Failed:
		promise.reject(resp.get_error())
		return
	var res: HTTP.Response = resp.get_result()
	promise.resolve(res.json())

func _process_rooms(result, promise: Promise):
	var list = []
	for data in result:
		list.append(RoomInfo.new(data))
	return list
