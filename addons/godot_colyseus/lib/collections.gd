extends Object

const EventListener = preload("res://addons/godot_colyseus/lib/listener.gd")
const SchemaInterface = preload("res://addons/godot_colyseus/lib/schema_interface.gd")

class Collection extends SchemaInterface:
	var sub_type
	
	func meta_get_subtype(index):
		return sub_type

class ArraySchema extends Collection:
	var items = []
	
	func clear(decoding: bool = false):
		items.clear()

	func meta_get(index):
		if items.size() > index:
			return items[index]
		return null

	func meta_get_key(index):
		return str(index)

	func meta_set(index, key, value):
		_set_item(index, value)

	func meta_remove(index):
		assert(items.size() > index)
		items.remove_at(index)
	
	func _set_item(index, value):
		if items.size() > index:
			items[index] = value
		else:
			while items.size() < index - 1:
				items.append(null)
			items.append(value)
	
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
		_counter = 0

	func meta_get(index):
		if _keys.size() > index:
			return items[_keys[index]]
		return null

	func meta_get_key(index):
		return _keys[index]

	func meta_set(index, key, value):
		_keys[index] = key
		items[key] = value

	func meta_remove(index):
		if not _keys.has(index):
			return
		items.erase(_keys[index])
		_keys.erase(index)
	
	func at(key: String):
		return items[key]
	
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
	
class SetSchema extends Collection:
	var _counter = 0
	var items = {}
	
	func clear(decoding: bool = false):
		items.clear()
		_counter = 0

	func meta_get(index):
		if items.size() > index:
			return items[index]
		return null

	func meta_get_key(index):
		return str(index)
		
	func meta_set(index, key, value):
		_set_item(index, value)

	func meta_remove(index):
		items.erase(index)
	
	func _set_item(index, value):
		if items.size() > index:
			items[index] = value
		else:
			while items.size() < index - 1:
				items.append(null)
			items.append(value)
			
	func _to_string():
		return JSON.stringify(items)
	
	func to_object():
		return items

class CollectionSchema extends Collection:
	var items = []
	
	func clear(decoding: bool = false):
		items.clear()

	func meta_get(index):
		if items.size() > index:
			return items[index]
		return null
		
	func meta_get_key(index):
		return str(index)

	func meta_set(index, key, value):
		_set_item(index, value)

	func meta_remove(index):
		items.erase(index)
	
	func _set_item(index, value):
		if items.size() > index:
			items[index] = value
		else:
			while items.size() < index - 1:
				items.append(null)
			items.append(value)
	
	func _to_string():
		return JSON.stringify(items)
	
	func to_object():
		return items
