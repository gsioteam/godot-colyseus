extends Object

const EventListener = preload("res://addons/godot_colyseus/lib/listener.gd")
const SchemaInterface = preload("res://addons/godot_colyseus/lib/schema_interface.gd")
const OP = preload("res://addons/godot_colyseus/lib/operations.gd")

class Collection extends SchemaInterface:
	var sub_type
	var _index_by_ref_id = {}
	
	func meta_get_subtype(index):
		return sub_type

	func setIndex(index, key):
		pass

	func getIndex(index):
		return index

	func find_index_by_ref_id(ref_id):
		return _index_by_ref_id.get(ref_id, -1)

	func _track_ref(index, value):
		if value is SchemaInterface and value.id != null:
			_index_by_ref_id[value.id] = index

	func _untrack_ref(value):
		if value is SchemaInterface and value.id != null:
			_index_by_ref_id.erase(value.id)

class ArraySchema extends Collection:
	var items = []
	
	func clear(decoding: bool = false):
		items.clear()
		_index_by_ref_id.clear()

	func meta_get(index):
		if items.size() > index:
			return items[index]
		return null

	func meta_get_key(index):
		return str(index)

	func meta_set(index, key, value, operation = OP.REPLACE):
		_set_item(index, value, operation)

	func meta_remove(index):
		assert(items.size() > index)
		var old = items[index]
		_untrack_ref(old)
		items.remove_at(index)
		_rebuild_ref_indexes()
		return old
	
	func _set_item(index, value, operation = OP.REPLACE):
		if operation == OP.MOVE or operation == OP.MOVE_AND_ADD or operation == OP.DELETE_AND_MOVE:
			var current_index = items.find(value)
			if current_index >= 0:
				items.remove_at(current_index)
				if current_index < index:
					index -= 1
		if items.size() > index:
			_untrack_ref(items[index])
			items[index] = value
		else:
			while items.size() < index:
				items.append(null)
			items.append(value)
		_rebuild_ref_indexes()

	func reverse():
		items.reverse()
		_rebuild_ref_indexes()

	func remove_by_ref_id(ref_id):
		var index = find_index_by_ref_id(ref_id)
		if index >= 0:
			return meta_remove(index)
		return null

	func _rebuild_ref_indexes():
		_index_by_ref_id.clear()
		for i in range(items.size()):
			_track_ref(i, items[i])
	
	func meta_set_self(value):
		items = value
	
	func at(index: int):
		return items[index]
		
	func size() -> int:
		return items.size()
	
	func _to_string():
		return JSON.stringify(items)
	
	func to_object():
		return items

class MapSchema extends Collection:
	var _keys = {}
	var items = {}
	var _counter = 0
	
	func clear(decoding: bool = false):
		items.clear()
		_keys.clear()
		_index_by_ref_id.clear()
		_counter = 0

	func meta_get(index):
		if _keys.has(index):
			return items.get(_keys[index])
		return null

	func meta_get_key(index):
		if not _keys.has(index):
			return index
		return _keys[index]

	func meta_set(index, key, value, operation = OP.REPLACE):
		if _keys.has(index):
			_untrack_ref(items.get(_keys[index]))
		_keys[index] = key
		items[key] = value
		_track_ref(index, value)

	func meta_remove(index):
		if not _keys.has(index):
			return null
		var key = _keys[index]
		var old = items.get(key)
		_untrack_ref(old)
		items.erase(key)
		_keys.erase(index)
		return old

	func setIndex(index, key):
		_keys[index] = key

	func getIndex(index):
		return _keys.get(index)
	
	func at(key: String):
		return items.get(key)
	
	func put(key: String, value):
		_keys[_counter] = key
		items[key] = value
		++_counter
	
	func _to_string():
		return JSON.stringify(items)
	
	func to_object():
		return items
	
	func keys():
		var list = []
		for k in _keys:
			list.append(_keys[k])
		return list
	
	func size():
		return _keys.size()
		
	func has(key: String):
		return items.has(key)
	
class SetSchema extends Collection:
	var _counter = 0
	var items = {}
	
	func clear(decoding: bool = false):
		items.clear()
		_index_by_ref_id.clear()
		_counter = 0

	func meta_get(index):
		if items.size() > index:
			return items[index]
		return null

	func meta_get_key(index):
		return str(index)
		
	func meta_set(index, key, value, operation = OP.REPLACE):
		_set_item(index, value)

	func meta_remove(index):
		var old = items.get(index)
		_untrack_ref(old)
		items.erase(index)
		return old
	
	func _set_item(index, value):
		_untrack_ref(items.get(index))
		items[index] = value
		_track_ref(index, value)
			
	func _to_string():
		return JSON.stringify(items)
	
	func to_object():
		return items

class CollectionSchema extends Collection:
	var items = []
	
	func clear(decoding: bool = false):
		items.clear()
		_index_by_ref_id.clear()

	func meta_get(index):
		if items.size() > index:
			return items[index]
		return null
		
	func meta_get_key(index):
		return str(index)

	func meta_set(index, key, value, operation = OP.REPLACE):
		_set_item(index, value)

	func meta_remove(index):
		var old = null
		if items.size() > index:
			old = items[index]
			_untrack_ref(old)
		items.remove_at(index)
		_rebuild_ref_indexes()
		return old
	
	func _set_item(index, value):
		if items.size() > index:
			_untrack_ref(items[index])
			items[index] = value
		else:
			while items.size() < index:
				items.append(null)
			items.append(value)
		_rebuild_ref_indexes()

	func _rebuild_ref_indexes():
		_index_by_ref_id.clear()
		for i in range(items.size()):
			_track_ref(i, items[i])
	
	func _to_string():
		return JSON.stringify(items)
	
	func to_object():
		return items
