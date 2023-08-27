extends RefCounted

const promises = preload("res://addons/godot_colyseus/lib/promises.gd")
const Promise = promises.Promise;
const RunPromise = promises.RunPromise;
const HTTP = preload("res://addons/godot_colyseus/lib/http.gd")
const CRoom = preload("res://addons/godot_colyseus/lib/room.gd")
const RoomInfo = preload("res://addons/godot_colyseus/lib/room_info.gd")

var endpoint: String

func _init(endpoint: String):
	self.endpoint = endpoint

func join_or_create(schema_type: GDScript, room_name: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		_create_match_make_request, 
		["joinOrCreate", room_name, options, schema_type])

func create(schema_type: GDScript, room_name: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		_create_match_make_request, 
		["create", room_name, options, schema_type])

func join(schema_type: GDScript, room_name: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		_create_match_make_request, 
		["join", room_name, options, schema_type])

func join_by_id(schema_type: GDScript, room_id: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		_create_match_make_request, 
		["joinById", room_id, options, schema_type])

func reconnect(schema_type: GDScript, reconnection_token: String) -> Promise:
	var arr = reconnection_token.split(":")
	if arr.size() == 2:
		var room_id = arr[0]
		var token = arr[1]
		return RunPromise.new(
			_create_match_make_request, 
			["reconnect", room_id, {"reconnectionToken": token}, schema_type])
	else:
		var fail = Promise.new()
		fail.reject("Invalidate `reconnection_token`")
		return fail

func get_available_rooms(room_name:String) -> Promise:
	var path = "/matchmake/" + room_name
	return RunPromise.new(
		_http_get,
		[path, {"Accept": "application/json"}]
	).then(_process_rooms)

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
		await resp.completed
	if resp.get_state() == Promise.State.Failed:
		promise.reject(resp.get_error())
		return
	var res: HTTP.Response = resp.get_data()
	var response = res.json()
	
	if response.get('code') != null:
		promise.reject(response['error'])
		return
	var room = CRoom.new(response["room"]["name"], schema_type)
	room.room_id = response["room"]["roomId"]
	room.session_id = response["sessionId"]
	
	room.connect_remote(_build_endpoint(response["room"], { "sessionId": room.session_id }))
	
	room.on_join.once(Callable(self, "_room_joined"), [promise, room])
	room.on_error.once(Callable(self, "_room_error"), [promise, room])

func _room_joined(promise: Promise, room: CRoom):
	room.on_error.off(Callable(self, "_room_error"))
	promise.resolve(room)

func _room_error(code: int, message: String, promise: Promise, room: CRoom):
	promise.reject(str("[", code, "]", message))

func _build_endpoint(room: Dictionary, options: Dictionary = {}):
	var params = PackedStringArray()
	for name in options.keys():
		params.append(name + "=" + options[name])
	return endpoint + "/" + room["processId"] + "/" + room["roomId"] + "?" + "&".join(params)

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
		await resp.completed
	if resp.get_state() == Promise.State.Failed:
		promise.reject(resp.get_error())
		return
	var res: HTTP.Response = resp.get_data()
	promise.resolve(res.json())

func _process_rooms(result, promise: Promise):
	var list = []
	for data in result:
		list.append(RoomInfo.new(data))
	return list
