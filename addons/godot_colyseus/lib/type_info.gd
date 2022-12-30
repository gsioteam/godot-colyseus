extends Object

const Decoder = preload("res://addons/godot_colyseus/lib/decoder.gd")
const types = preload("res://addons/godot_colyseus/lib/types.gd")
const collections = preload("res://addons/godot_colyseus/lib/collections.gd")

var type: String
var sub_type

func _init(type: String,sub_type = null):
	self.type = type
	self.sub_type = sub_type

func is_schema_type():
	return type == types.REF or type == types.MAP or type == types.ARRAY or type == types.COLLECTION or type == types.SET

func create():
	match type:
		types.REF:
			return sub_type.new()
		types.MAP:
			var obj = collections.MapSchema.new()
			obj.sub_type = sub_type
			return obj
		types.ARRAY:
			var obj = collections.ArraySchema.new()
			obj.sub_type = sub_type
			return obj
		types.SET:
			var obj = collections.SetSchema.new()
			obj.sub_type = sub_type
			return obj
		types.COLLECTION:
			var obj = collections.CollectionSchema.new()
			obj.sub_type = sub_type
			return obj

func decode(decoder: Decoder):
	match type:
		types.REF:
			var obj = sub_type.new()
			obj.id = decoder.number()
			return obj
		types.MAP:
			var obj = collections.MapSchema.new()
			obj.id = decoder.number()
			obj.sub_type = sub_type
			return obj
		types.ARRAY:
			var obj = collections.ArraySchema.new()
			obj.id = decoder.number()
			obj.sub_type = sub_type
			return obj
		types.SET:
			var obj = collections.SetSchema.new()
			obj.id = decoder.number()
			obj.sub_type = sub_type
			return obj
		types.COLLECTION:
			var obj = collections.CollectionSchema.new()
			obj.id = decoder.number()
			obj.sub_type = sub_type
			return obj
		types.STRING:
			return decoder.read_utf8()
		types.NUMBER:
			return decoder.number()
		types.BOOLEAN:
			return decoder.reader.get_u8() > 0
		types.INT8:
			return decoder.reader.get_8()
		types.UINT8:
			return decoder.reader.get_u8()
		types.INT16:
			return decoder.reader.get_16()
		types.UINT16:
			return decoder.reader.get_u16()
		types.INT32:
			return decoder.reader.get_32()
		types.UINT32:
			return decoder.reader.get_u32()
		types.INT64:
			return decoder.reader.get_64()
		types.UINT64:
			return decoder.reader.get_u64()
		types.FLOAT32:
			return decoder.reader.get_float()
		types.FLOAT64:
			return decoder.reader.get_double()
		_:
			assert(true) #,str("Unkown support type:", type))

