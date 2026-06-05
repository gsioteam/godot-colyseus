
extends RefCounted

const Schema = preload("res://addons/godot_colyseus/lib/schema.gd")
const Decoder = preload("res://addons/godot_colyseus/lib/decoder.gd")
const Types = preload("res://addons/godot_colyseus/lib/types.gd")
const TypeInfo = preload("res://addons/godot_colyseus/lib/type_info.gd")

class Serializer:
	
	func set_state(decoder):
		pass
		
	func get_state():
		pass
	
	func patch(decoder):
		pass
	
	func teardown():
		pass
	
	func handshake(decoder):
		pass
	

class NoneSerializer extends Serializer:
	pass

class ReflectionField extends Schema:
	
	static func define_fields():
		return [
			Schema.Field.new("name", Schema.Types.STRING),
			Schema.Field.new("type", Schema.Types.STRING),
			Schema.Field.new("referenced_type", Schema.Types.NUMBER),
		]
	
	func test(field, reflection: Reflection) -> bool:
		if self.type != field.current_type.to_string() or self.name != field.name:
			var str1 = str(field.name, '-', self.name)
			var str2 = str(field.current_type, '-', self.type)
			printerr("Field not match ", str1, " : ", str2)
			return false
		var base_type = self.type.split(":")[0]
		var uses_referenced_schema = base_type == Schema.Types.REF or (self.type.find(":") == -1 and (
			base_type == Schema.Types.MAP or
			base_type == Schema.Types.ARRAY or
			base_type == Schema.Types.SET or
			base_type == Schema.Types.COLLECTION
		))
		if uses_referenced_schema and self.referenced_type != null and self.referenced_type >= 0:
			var schema_type = field.current_type.sub_type
			if schema_type != null and schema_type is TypeInfo:
				schema_type = schema_type.sub_type
			if schema_type == null:
				printerr("Missing referenced schema type for field ", self.name)
				return false
			var type = reflection.types.at(self.referenced_type)
			return type.test(schema_type, reflection)
		return true

class ReflectionType extends Schema:
	
	static func define_fields():
		return [
			Schema.Field.new("id", Schema.Types.NUMBER),
			Schema.Field.new("extendsId", Schema.Types.NUMBER),
			Schema.Field.new("fields", Schema.Types.ARRAY, ReflectionField),
		]
	
	func test(schema_type, reflection: Reflection) -> bool:
		if not schema_type is GDScript:
			printerr("Type schema_type not match ", self.id)
			return false
		var fields = schema_type.define_fields()
		var length = fields.size()
		if length != self.fields.size():
			printerr("Type fields count not match ", self.id)
			return false
		for i in range(length):
			var field = self.fields.at(i)
			if not field.test(fields[i], reflection):
				return false
		return true

class Reflection extends Schema:
	
	static func define_fields():
		return [
			Schema.Field.new("types", Schema.Types.ARRAY, ReflectionType),
			Schema.Field.new("root_type", Schema.Types.NUMBER),
		]
	
	func test(schema_type: GDScript) -> bool:
		return self.types.at(self.root_type).test(schema_type, self)

class SchemaSerializer extends Serializer:
	var state
	var schema_type: GDScript
	
	func _init(schema_type):
		self.schema_type = schema_type
		self.state = schema_type.new()
	
	func handshake(decoder):
		var reflection = Reflection.new()
		reflection.decode(decoder)
		assert(reflection.test(schema_type),"Can not detect schema type")
	
	func set_state(decoder):
		state.decode(decoder)
	
	func get_state():
		return state
	
	func patch(decoder):
		state.decode(decoder)
	

static func getSerializer(id: String, schema_type: GDScript = null) -> Serializer:
	match id:
		"schema":
			return SchemaSerializer.new(schema_type)
		"none":
			return NoneSerializer.new()
	return null
