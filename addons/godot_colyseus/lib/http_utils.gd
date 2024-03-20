const HTTP = preload("res://addons/godot_colyseus/lib/http.gd")
const promises = preload("res://addons/godot_colyseus/lib/promises.gd")
const Promise = promises.Promise;

static func GET(promise: Promise, endpoint: String, path: String, headers: Dictionary):
	if endpoint.begins_with("ws"):
		endpoint = endpoint.replace("ws", "http")
	var http = HTTP.new(endpoint)
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

static func POST(promise: Promise, endpoint: String, path: String, body: Dictionary, headers: Dictionary = {"Accept": "application/json", "Content-Type": "application/json"}):
	if endpoint.begins_with("ws"):
		endpoint = endpoint.replace("ws", "http")
	var http = HTTP.new(endpoint)
	var req = HTTP.RequestInfo.new("POST", path)
	for key in headers.keys():
		req.add_header(key, headers[key])
	req.body = body
	
	var resp = http.fetch(req)
	
	if resp.get_state() == Promise.State.Waiting:
		await resp.completed
	if resp.get_state() == Promise.State.Failed:
		promise.reject(resp.get_error())
		return
	var res: HTTP.Response = resp.get_data()
	promise.resolve(res.json())
