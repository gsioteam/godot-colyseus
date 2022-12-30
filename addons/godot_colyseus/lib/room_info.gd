extends RefCounted

var clients: int
var created_at: String
var max_clients: int
var name: String
var process_id: String
var room_id: String

func _init(dic):
	clients = dic.get('clients')
	created_at = dic.get('createdAt')
	var num = dic.get('maxClients')
	if num != null:
		max_clients = num
	name = dic.get('name')
	process_id = dic.get('processId')
	room_id = dic.get('roomId')
