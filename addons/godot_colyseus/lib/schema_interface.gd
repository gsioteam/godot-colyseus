extends Reference

const Types = preload("./types.gd")

class Ref:
	var value
	var type_info
	
	func _init(value, type_info):
		self.value = value
		self.type_info = type_info

var id
var parent
var parent_index: int

func clear(decoding: bool = false):
	assert(false)

func meta_get(index):
	assert(false)
	
func meta_get_key(index) -> String:
	assert(false)
	return ""

func meta_get_subtype(index):
	assert(false)

func meta_set(index, key, value):
	assert(false)
	return null

func meta_remove(index):
	assert(false)

func set_parent(np, pindex):
	if parent != null:
		parent.meta_remove(parent_index)
	parent = np
	parent_index = pindex

func trigger(event: String, argv = [], path: PoolStringArray = [], target = self):
	if parent == null:
		return
	path.append(parent.meta_get_key(parent_index))
	parent.trigger(event, argv, path, target)

func to_object():
	assert(false)
