extends "./schema_interface.gd"

const col = preload("res://addons/godot_colyseus/lib/collections.gd")
const OP = preload("res://addons/godot_colyseus/lib/operations.gd")
const TypeInfo = preload("res://addons/godot_colyseus/lib/type_info.gd")

const END_OF_STRUCTURE = 0xc1
const NIL = 0xc0
const INDEX_CHANGE = 0xd4

const Decoder = preload("res://addons/godot_colyseus/lib/decoder.gd")
const EventListener = preload("res://addons/godot_colyseus/lib/listener.gd")
const SchemaInterface = preload("res://addons/godot_colyseus/lib/schema_interface.gd")

class Field:
	const Types = preload("res://addons/godot_colyseus/lib/types.gd")
	var index: int
	var name: String
	var value
	var current_type
	
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

var _fields: Array = []
var _field_index = {}

var _refs = {}

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
#	remove_at		Delete sub object， paramaters [current, old_value, key]
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
		Types.ARRAY:
			assert(type.sub_type != null) #,"Schema type is requested")
			field.value = col.Collection.new()
		Types.SET:
			assert(type.sub_type != null) #,"Schema type is requested")
		Types.COLLECTION:
			assert(type.sub_type != null) #,"Schema type is requested")
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
	var ref: Ref = Ref.new(self, TypeInfo.new(Types.REF))
	_refs[ref_id] = ref
	var changes = []
	var changed_objects = {}
	
	while decoder.has_more():
		var byte = decoder.reader.get_u8()
		
		if byte == OP.SWITCH_TO_STRUCTURE:
			ref_id = decoder.number()
			
			var next_ref = _refs[ref_id]
			
			assert(next_ref != null) #,str('"refId" not found:', ref_id))
			
			ref = next_ref
			
			continue
		
		var is_schema = ref.type_info.type == Types.REF
		
		var operation = byte
		if is_schema:
			operation = (byte >> 6) << 6
		
		
		if operation == OP.CLEAR:
			ref.value.clear(true)
			if ref.value is SchemaInterface:
				changes.append({
					target = ref.value,
					event = "clear",
					argv = []
				})
			continue
		
		var field_index = byte % _re_replace(operation)
		if not is_schema:
			field_index = decoder.number()
		
		var ref_value = ref.value
		if ref_value is SchemaInterface:
			var old = ref_value.meta_get(field_index)
			var new
			var key = field_index 
			if ref.type_info.type != Types.MAP:
				key = ref_value.meta_get_key(field_index)
			
			if operation == OP.DELETE:
				ref_value.meta_remove(field_index)
			else:
				if ref.type_info.type == Types.MAP:
					key = decoder.read_utf8()
				var type: TypeInfo = ref_value.meta_get_subtype(field_index)
				if type.is_schema_type():
					var new_ref_id = decoder.number()
					if _refs.has(new_ref_id):
						new = _refs[new_ref_id].value
					else:
						if operation != OP.REPLACE:
							new = type.create()
							new.id = new_ref_id
							_refs[new_ref_id] = Ref.new(new, type)
				else:
					new = type.decode(decoder)
			
			if old != new:
				
				if old == null:
					changes.append({
						target = ref_value,
						event = "add",
						argv = [new, key]
					})
				elif new == null:
					changes.append({
						target = ref_value,
						event = "remove_at",
						argv = [old, key]
					})
				else:
					changes.append({
						target = ref_value,
						event = "replace",
						argv = [new, key]
					})
				
				if old != null:
					if old is SchemaInterface && old.id != null:
						changes.append({
							target = old,
							event = "delete",
							argv = []
						})
						_refs.erase(old.id)
				
				if new != null:
					ref_value.meta_set(field_index, key, new)
					if new is SchemaInterface:
						changes.append({
							target = new,
							event = "create",
							argv = []
						})
						new.set_parent(ref_value, field_index)
				elif old != null:
					ref_value.meta_remove(field_index)
				
				changed_objects[ref_value] = true
	
	for change in changes:
		var target = change.target
		target.trigger(change.event, change.argv)
	
	for target in changed_objects.keys():
		target.trigger("change", [])
	
	return 0


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

func meta_set(index, key, value):
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

func trigger(event: String, argv = [], path: PackedStringArray = PackedStringArray(), target = self):
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
