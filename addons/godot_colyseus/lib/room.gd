extends RefCounted

const FrameRunner = preload("res://addons/godot_colyseus/lib/frame_runner.gd")
const EventListener = preload("res://addons/godot_colyseus/lib/listener.gd")
const ser = preload("res://addons/godot_colyseus/lib/serializer.gd")
const Decoder = preload("res://addons/godot_colyseus/lib/decoder.gd")
const Encoder = preload("res://addons/godot_colyseus/lib/encoder.gd")
const MsgPack = preload("res://addons/godot_colyseus/lib/msgpack.gd")

const CODE_HANDSHAKE = 9
const CODE_JOIN_ROOM = 10
const CODE_ERROR = 11
const CODE_LEAVE_ROOM = 12
const CODE_ROOM_DATA = 13
const CODE_ROOM_STATE = 14
const CODE_ROOM_STATE_PATCH = 15
const CODE_ROOM_DATA_SCHEMA = 16

const ERROR_MATCHMAKE_NO_HANDLER = 4210
const ERROR_MATCHMAKE_INVALID_CRITERIA = 4211
const ERROR_MATCHMAKE_INVALID_ROOM_ID = 4212
const ERROR_MATCHMAKE_UNHANDLED = 4213
const ERROR_MATCHMAKE_EXPIRED = 4214

const ERROR_AUTH_FAILED = 4215
const ERROR_APPLICATION_ERROR = 4216

var room_name: String
var room_id: String
var session_id: String
var serializer: ser.Serializer
var ws: WebSocketPeer
var frame_runner: FrameRunner
var reconnection_token: String

var schema_type: GDScript

var _has_joined = false
func has_joined() -> bool:
	return _has_joined

# [code: int, message: String]
var on_error: EventListener = EventListener.new()

# []
var on_leave: EventListener = EventListener.new()

# []
var on_join: EventListener = EventListener.new()

# [state: Schema]
var on_state_change: EventListener = EventListener.new()

# [data]
var _messages = {}
func on_message(event: String, new_listener: bool = true) -> EventListener:
	var listener
	if not _messages.has(event) or new_listener:
		listener = EventListener.new()
		_messages[event] = listener
	else:
		listener = _messages[event]
	return listener

func _init(room_name: String,schema_type: GDScript):
	self.room_name = room_name
	self.schema_type = schema_type
	ws = WebSocketPeer.new()
#	ws.connect("connection_established",Callable(self,"_connection_established"))
#	ws.connect("connection_error",Callable(self,"_connection_error"))
#	ws.connect("connection_closed",Callable(self,"_connection_closed"))
#	ws.connect("data_received",Callable(self,"_on_data"))
	
	frame_runner = FrameRunner.new(_on_frame)
	


func _connection_established(protocol):
	pass

func _connection_error():
	frame_runner.stop()

func _connection_closed(was_clean: bool):
	frame_runner.stop()

func _on_data():
	var data = ws.get_packet()
	var reader = StreamPeerBuffer.new()
	reader.data_array = data
	
	var decoder = Decoder.new(reader)
	var code = reader.get_u8()
	match code:
		CODE_JOIN_ROOM:
			
			var token = reader.get_string(reader.get_u8())
			
			var serializer_id = reader.get_string(reader.get_u8())
			
			if serializer == null:
				serializer = ser.getSerializer(serializer_id, schema_type)
			
			if decoder.has_more():
				if serializer:
					serializer.handshake(decoder)
				else:
					on_error.emit([1, "Can not find serializer"])
					return
			
			self.reconnection_token = str(room_id, ":", token)
			_has_joined = true
			on_join.emit()
			send_raw([CODE_JOIN_ROOM])
		CODE_ERROR:
			var message = decoder.read_utf8()
			on_error.emit([0, message])
		CODE_LEAVE_ROOM:
			leave()
		CODE_ROOM_DATA:
			var type
			if decoder.is_number():
				type = str('i', decoder.number())
			else:
				type = decoder.read_utf8()
			
			var listener = on_message(type, false)
			if listener != null:
				var ret = decoder.unpack()
				if ret == null:
					ret = {}
				listener.emit([ret])
			
		CODE_ROOM_STATE:
			serializer.set_state(decoder)
			on_state_change.emit([serializer.get_state()])
		CODE_ROOM_STATE_PATCH:
			serializer.patch(decoder)
			on_state_change.emit([serializer.get_state()])
		CODE_ROOM_DATA_SCHEMA:
			print("Receive message CODE_ROOM_DATA_SCHEMA")

func connect_remote(url: String):
	var _url = url
	if url.begins_with("http:"):
		_url = url.replace("http:", "ws:")
	elif url.begins_with("https:"):
		_url = url.replace("https:", "wss:")
	ws.connect_to_url(_url)
	frame_runner.start()

func _on_frame():
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				_on_data()
		WebSocketPeer.STATE_CLOSED:
			var code = ws.get_close_code()
			var reason = ws.get_close_reason()
			_connection_closed(true)

func send_raw(bytes: PackedByteArray):
	ws.send(bytes)

func send(type, message = null):
	var buffer = StreamPeerBuffer.new() 
	buffer.put_u8(CODE_ROOM_DATA)
	var encoder = Encoder.new(buffer)
	
	if typeof(type) == TYPE_STRING:
		encoder.string(type)
	else:
		encoder.number(type)
	
	if message != null:
		var result = MsgPack.encode(message, buffer)
		assert(result.error == OK)
	
	send_raw(buffer.data_array)

func leave(consented = true):
	if not room_id.is_empty():
		if consented:
			send_raw([CODE_LEAVE_ROOM])
		else:
			ws.disconnect_from_host()
	else:
		on_leave.emit()

func get_state():
	return serializer.get_state()
