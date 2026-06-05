extends "./schema_interface.gd"

const col = preload("res://addons/godot_colyseus/lib/collections.gd")
const OP = preload("res://addons/godot_colyseus/lib/operations.gd")
const TypeInfo = preload("res://addons/godot_colyseus/lib/type_info.gd")

const END_OF_STRUCTURE = 0xc1
const NIL = 0xc0
const INDEX_CHANGE = 0xd4
const TYPE_ID = OP.TYPE_ID

const Decoder = preload("res://addons/godot_colyseus/lib/decoder.gd")
const EventListener = preload("res://addons/godot_colyseus/lib/listener.gd")
const SchemaInterface = preload("res://addons/godot_colyseus/lib/schema_interface.gd")

class Field:
	const Types = preload("res://addons/godot_colyseus/lib/types.gd")
	var index: int
	var name: String
	var value
	var current_type: TypeInfo
	
	func _init(name: String,type: String,schema_type = null):
		current_type = TypeInfo.new(type)
		if schema_type is String:
			current_type.sub_type = TypeInfo.new(schema_type)
		elif schema_type is GDScript:
			if type == Types.REF:
				current_type.sub_type = schema_type
			else:
				current_type.sub_type = TypeInfo.new(Types.REF, schema_type)
		elif schema_type is TypeInfo:
			current_type.sub_type = schema_type
		self.name = name
	
	func _to_string():
		if current_type:
			return current_type.to_string()
		else:
			return 'null'

var _fields: Array = []
var _field_index = {}

var _refs = {}
var _deleted_refs = []

var _change_listeners = {}

func _get_property_list():
	var result = []
	for field in _fields:
		result.append({
			name = field.name,
			type = Types.to_gd_type(field.current_type.type),
			usage = PROPERTY_USAGE_DEFAULT
		})
	return result

func _get(property):
	if _field_index.has(property):
		var value = _field_index[property].value
		if value is SchemaInterface:
			pass
		return value
	return null

func _set(property, value):
	if _field_index.has(property):
		var field = _field_index[property]
		var old = field.value
		if old is SchemaInterface:
			pass
		field.value = value
		return true
	return false

# [event: String, target, key_or_index]
# path format {path}:{action}
# {action} is one of:
#	add  		Create sub object, paramaters [current, new_value, key]
#	remove		Delete sub object， paramaters [current, old_value, key]
#	replace		Replace sub object， paramaters [current, new_value, key]
#	delete		Current object is deleted, paramaters [current]
#	create		Current object is created, paramaters [current]
#	change		Current object's attributes has changed, paramaters [current]
#	clear		Current Array or Map has cleared, paramaters [current]
func listen(path: String) -> EventListener:
	if not _change_listeners.has(path):
		_change_listeners[path] = EventListener.new()
	return _change_listeners[path]

static func define_fields() -> Array:
	return []

func _init():
	_fields = self.get_script().define_fields()
	var counter = 0
	for field in _fields:
		field.index = counter
		_setup_field(field)
		counter += 1

func _setup_field(field: Field):
	_field_index[field.name] = field
	var type = field.current_type
	match type.type:
		Types.MAP:
			assert(type.sub_type != null) #,"Schema type is requested")
			field.value = type.create()
		Types.ARRAY:
			assert(type.sub_type != null) #,"Schema type is requested")
			field.value = type.create()
		Types.SET:
			assert(type.sub_type != null) #,"Schema type is requested")
			field.value = type.create()
		Types.COLLECTION:
			assert(type.sub_type != null) #,"Schema type is requested")
			field.value = type.create()
		Types.REF:
			assert(type.sub_type != null) #,"Schema type is requested")
		Types.NUMBER, Types.FLOAT32, Types.FLOAT64:
			field.value = 0.0
		Types.INT8, Types.UINT8, Types.INT16, Types.UINT16, Types.INT32, Types.UINT32, Types.INT64, Types.UINT64:
			field.value = 0
		Types.STRING:
			field.value = ""

func get_fields():
	return _fields

func decode(decoder: Decoder) -> int:
	var ref_id = 0
	var ref: Ref = _ensure_ref(0, self, TypeInfo.new(Types.REF))
	var changes = []
	var changed_objects = {}
	
	while decoder.has_more():
		var byte = decoder.reader.get_u8()
		
		if byte == OP.SWITCH_TO_STRUCTURE:
			ref_id = decoder.number()
			if not _refs.has(ref_id):
				printerr(str('"refId" not found: ', ref_id))
				_skip_current_structure(decoder)
				continue
			ref = _refs[ref_id]
			continue
		
		if ref.type_info.type == Types.REF:
			_decode_schema_operation(decoder, ref_id, ref, byte, changes, changed_objects)
		else:
			_decode_collection_operation(decoder, ref_id, ref, byte, changes, changed_objects)
	
	for change in changes:
		var target = change.target
		if target is SchemaInterface:
			target.trigger(change.event, change.argv)
	
	for target in changed_objects.keys():
		if target is SchemaInterface:
			target.trigger("change", [])
	
	_garbage_collect_deleted_refs()
	return 0

func _decode_schema_operation(decoder: Decoder, ref_id: int, ref: Ref, byte: int, changes: Array, changed_objects: Dictionary):
	var operation = (byte >> 6) << 6
	var field_index = byte % _re_replace(operation)
	var ref_value = ref.value
	if not ref_value is SchemaInterface:
		return
	if field_index >= ref_value.get_fields().size():
		printerr(str("@colyseus/schema: field not defined at index ", field_index))
		_skip_current_structure(decoder)
		return
	var field = ref_value.get_fields()[field_index]
	var key = field.name
	var type: TypeInfo = field.current_type
	_apply_decoded_value(decoder, ref_id, ref_value, field_index, key, operation, type, changes, changed_objects)

func _decode_collection_operation(decoder: Decoder, ref_id: int, ref: Ref, operation: int, changes: Array, changed_objects: Dictionary):
	var ref_value = ref.value
	if not ref_value is SchemaInterface:
		return
	
	if operation == OP.CLEAR:
		_remove_child_refs(ref_value, changes)
		ref_value.clear(true)
		changes.append({ target = ref_value, event = "clear", argv = [] })
		changed_objects[ref_value] = true
		return
	
	if operation == OP.REVERSE and ref.type_info.type == Types.ARRAY:
		if ref_value.has_method("reverse"):
			ref_value.reverse()
		changed_objects[ref_value] = true
		return
	
	if operation == OP.DELETE_BY_REFID and ref.type_info.type == Types.ARRAY:
		var delete_ref_id = decoder.number()
		var old = null
		if ref_value.has_method("remove_by_ref_id"):
			old = ref_value.remove_by_ref_id(delete_ref_id)
		_mark_ref_deleted(delete_ref_id)
		if old != null:
			changes.append({ target = ref_value, event = "remove", argv = [old, ""] })
			changed_objects[ref_value] = true
		return
	
	var field_index = decoder.number()
	var key = field_index
	if operation == OP.ADD_BY_REFID:
		var existing = _refs.get(field_index)
		if existing != null and ref_value.has_method("find_index_by_ref_id"):
			var existing_index = ref_value.find_index_by_ref_id(field_index)
			if existing_index >= 0:
				field_index = existing_index
	
	if (operation & OP.ADD) == OP.ADD:
		if ref.type_info.type == Types.MAP:
			key = decoder.read_utf8()
			if ref_value.has_method("setIndex"):
				ref_value.setIndex(field_index, key)
		else:
			key = ref_value.meta_get_key(field_index)
	else:
		key = ref_value.meta_get_key(field_index)
	
	_apply_decoded_value(decoder, ref_id, ref_value, field_index, key, operation, ref.type_info.sub_type, changes, changed_objects)

func _apply_decoded_value(decoder: Decoder, ref_id: int, ref_value: SchemaInterface, field_index: int, key, operation: int, type: TypeInfo, changes: Array, changed_objects: Dictionary):
	var old = ref_value.meta_get(field_index)
	var new = null
	
	if (operation & OP.DELETE) == OP.DELETE:
		var removed = ref_value.meta_remove(field_index)
		if removed != null:
			old = removed
		if old is SchemaInterface and old.id != null:
			_mark_ref_deleted(old.id)
	
	if operation != OP.DELETE:
		new = _decode_value(decoder, operation, type)
	
	if old != new:
		if old == null and new != null:
			changes.append({ target = ref_value, event = "add", argv = [new, key] })
		elif old != null and new == null:
			changes.append({ target = ref_value, event = "remove", argv = [old, key] })
		elif old != null and new != null:
			changes.append({ target = ref_value, event = "replace", argv = [new, key] })
		
		if old is SchemaInterface and old.id != null and old != new:
			changes.append({ target = old, event = "delete", argv = [] })
		
		if new != null:
			ref_value.meta_set(field_index, key, new, operation)
			if new is SchemaInterface:
				changes.append({ target = new, event = "create", argv = [] })
				new.set_parent(ref_value, field_index)
		
		changed_objects[ref_value] = true

func _decode_value(decoder: Decoder, operation: int, type: TypeInfo):
	if type == null:
		return null
	if type.type == Types.REF or type.type == Types.MAP or type.type == Types.ARRAY or type.type == Types.SET or type.type == Types.COLLECTION:
		var new_ref_id = decoder.number()
		var concrete_type = _get_instance_type(decoder, type)
		if _refs.has(new_ref_id):
			return _refs[new_ref_id].value
		if (operation & OP.ADD) == OP.ADD:
			var new_value = concrete_type.create()
			new_value.id = new_ref_id
			_ensure_ref(new_ref_id, new_value, concrete_type)
			return new_value
		return null
	return type.decode(decoder)

func _get_instance_type(decoder: Decoder, default_type: TypeInfo) -> TypeInfo:
	if decoder.has_more() and decoder.current_bit() == TYPE_ID:
		decoder.reader.get_u8()
		decoder.number()
		# Local schemas are user-provided GDScript classes. Consume TYPE_ID for protocol compatibility.
	return default_type

func _ensure_ref(ref_id: int, value, type_info: TypeInfo) -> Ref:
	var ref = Ref.new(value, type_info)
	_refs[ref_id] = ref
	return ref

func _mark_ref_deleted(ref_id):
	if ref_id == null:
		return
	if not _deleted_refs.has(ref_id):
		_deleted_refs.append(ref_id)

func _garbage_collect_deleted_refs():
	for ref_id in _deleted_refs:
		if ref_id != 0:
			_refs.erase(ref_id)
	_deleted_refs.clear()

func _remove_child_refs(ref_value: SchemaInterface, changes: Array):
	var values = []
	if ref_value.has_method("to_object"):
		var obj = ref_value.to_object()
		if obj is Array:
			values = obj
		elif obj is Dictionary:
			values = obj.values()
	for value in values:
		if value is SchemaInterface and value.id != null:
			_mark_ref_deleted(value.id)
			changes.append({ target = value, event = "delete", argv = [] })

func _skip_current_structure(decoder: Decoder):
	while decoder.has_more():
		if decoder.current_bit() == OP.SWITCH_TO_STRUCTURE:
			return
		decoder.reader.get_u8()


func _re_replace(operation):
	if operation == OP.REPLACE:
		return 255
	return operation

func clear(decoding: bool = false):
	pass

func meta_get(index):
	assert(_fields.size() > index)
	var field : Field = _fields[index]
	return field.value

func meta_get_key(index):
	assert(_fields.size() > index)
	var field : Field = _fields[index]
	return field.name

func meta_get_subtype(index):
	assert(_fields.size() > index)
	var field : Field = _fields[index]
	return field.current_type

func meta_set(index, key, value, operation = OP.REPLACE):
	assert(_fields.size() > index)
	var field : Field = _fields[index]
	field.value = value

func meta_remove(index):
	assert(_fields.size() > index)
	var field : Field = _fields[index]
	var old = field.value
	field.value = null
	return old

func _to_string():
	var obj = to_object()
	return JSON.stringify(obj)

func trigger(event: String, argv: Array = [], path: PackedStringArray = PackedStringArray(), target: Object = self):
	var path_copy = PackedStringArray(path)
	path_copy.reverse()
	var path_str = '/'.join(path_copy) + ":" + event
	if _change_listeners.has(path_str):
		var ls: EventListener = _change_listeners[path_str]
		argv.insert(0, target)
		ls.emit(argv)
	else:
		super.trigger(event, argv, path, target)

func to_object():
	var dic = {}
	for field in _fields:
		if field.value is SchemaInterface:
			dic[field.name] = field.value.to_object()
		else:
			dic[field.name] = field.value
	return dic
