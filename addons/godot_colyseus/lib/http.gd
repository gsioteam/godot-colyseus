extends RefCounted

const promises = preload("res://addons/godot_colyseus/lib/promises.gd")
const Promise = promises.Promise
const RunPromise = promises.RunPromise

var _connected = false
var _client_promise: promises.Promise

class RequestInfo:
	var method: String = "GET"
	var path: String = "/"
	var headers: PackedStringArray = []
	var body
	
	func _init(method: String = "GET",path: String = "/"):
		self.method = method
		self.path = path
	
	func add_header(key: String, value):
		headers.append(str(key, ": ", value))
		return self

	func http_method():
		match method.to_upper():
			"GET":
				return HTTPClient.METHOD_GET
			"POST": 
				return HTTPClient.METHOD_POST
			"PUT":
				return HTTPClient.METHOD_PUT
			"DELETE":
				return HTTPClient.METHOD_DELETE
			"HEAD":
				return HTTPClient.METHOD_HEAD
			"OPTIONS":
				return HTTPClient.METHOD_OPTIONS
	
	func get_body():
		if body == null:
			body = ""
		if body is Dictionary or body is Array:
			body = JSON.stringify(body)
		return body

class Response:
	var _response_chunks: Array = []
	var _body
	var _has_response = false
	
	var _status_code: int = 0
	var _content_length: int = 0
	var _headers
	
	func body() -> PackedByteArray:
		if _body == null:
			_body = PackedByteArray()
			for chunk in _response_chunks:
				_body.append_array(chunk)
		return _body
	
	func text() -> String:
		return body().get_string_from_utf8()
	
	func json():
		var test_json_conv = JSON.new()
		var err = test_json_conv.parse(text())
		if err == OK:
			return test_json_conv.get_data()
		print(str(test_json_conv.get_error_message(), ":", test_json_conv.get_error_line()))
		return null
		
	func headers() -> Dictionary:
		return _headers
	
	func status_code() -> int:
		return _status_code
	
	func content_length() -> int:
		return _content_length
		
	func _to_string():
		var lines = PackedStringArray()
		lines.append(str("StatusCode: ", status_code()))
		lines.append(str("ContentLength: ", content_length()))
		lines.append(str("Headers: "))
		var header = headers()
		for key in header.keys():
			lines.append(str("  ", key, ": ", header[key]))
		lines.append(str("Body: [", body().size(), "]"))
		return "\n".join(lines)

var _old_status

func _init(server: String):
	var regex = RegEx.new()
	regex.compile("(\\w+):\\/\\/([^\\/:]+)(:(\\d+))?")
	var result = regex.search(server)
	var scheme = result.get_string(1)
	var ssl = scheme == "https"
	var host = result.get_string(2)
	var portstr = result.get_string(4)
	var port = -1
	if portstr != "":
		port = int(portstr)
	_client_promise = promises.RunPromise.new(Callable(self, "_setup"), [host, port, ssl]);

func _setup(promise: promises.Promise, host, port, ssl):
	var client = HTTPClient.new()
	var error = client.connect_to_host(host, port, null)
	if error != OK:
		promise.reject(str("ErrorCode: ", error))
	var root = Engine.get_main_loop()
	while true:
		await root.process_frame
		client.poll()
		var status = client.get_status()
		
		match status:
			HTTPClient.STATUS_CONNECTED:
				promise.resolve(client)
				break
			HTTPClient.STATUS_DISCONNECTED:
				promise.reject("Disconnected from Host")
				break
			HTTPClient.STATUS_CANT_CONNECT:
				promise.reject("Can't Connect to Host")
				break

func _request(promise: Promise, request: RequestInfo):
	if _client_promise.get_state() == promises.Promise.State.Waiting:
		await _client_promise.completed
	if _client_promise.get_state() == Promise.State.Failed:
		promise.reject(_client_promise.get_error())
		return
	var client: HTTPClient = _client_promise.get_data()
	var body = request.get_body()
	var error
	if body is String:
		error = client.request(request.http_method(), request.path, request.headers, body)
	elif body is PackedByteArray:
		error = client.request_raw(request.http_method(), request.path, request.headers, body)
	else:
		promise.reject("Unsupport body type")
		return
	if error != OK:
		promise.reject(str("Error code ", error))
		return
	var root = Engine.get_main_loop()
	var response = Response.new()
	while true:
		await root.process_frame
		error = client.poll()
		var status = client.get_status()
		match status:
			HTTPClient.STATUS_DISCONNECTED:
				if response._has_response:
					promise.resolve(response)
				else:
					promise.reject("Disconnected from Host")
				return
			HTTPClient.STATUS_CANT_CONNECT:
				promise.reject("Can't Connect to Host")
				return
			HTTPClient.STATUS_CONNECTION_ERROR:
				promise.reject("Connection Error")
				return
			HTTPClient.STATUS_BODY:
				if not response._has_response:
					response._has_response = true
					response._status_code = client.get_response_code()
					response._content_length = client.get_response_body_length()
					response._headers = client.get_response_headers_as_dictionary()
				var chunk = client.read_response_body_chunk()
				if chunk.is_empty():
					continue
				response._response_chunks.append(chunk)
			HTTPClient.STATUS_CONNECTED:
				promise.resolve(response)
				return 
	pass

func fetch(request = null) -> Promise:
	if request == null:
		request = RequestInfo.new()
	elif request is String:
		var path = request
		request = RequestInfo.new()
		request.path = path
	return RunPromise.new(Callable(self, "_request"), [request])
