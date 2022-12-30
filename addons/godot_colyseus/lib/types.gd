extends Object

const REF = "ref"
const MAP = "map"
const ARRAY = "array"
const SET = "set"
const COLLECTION = "collection"
const STRING = "string"
const NUMBER = "number"
const BOOLEAN = "boolean"
const INT8 = "int8"
const UINT8 = "uint8"
const INT16 = "int16"
const UINT16 = "uint16"
const INT32 = "int32"
const UINT32 = "uint32"
const INT64 = "int64"
const UINT64 = "uint64"
const FLOAT32 = "float32"
const FLOAT64 = "float64"

static func to_gd_type(type: String) -> int:
	match type:
		REF:
			return TYPE_OBJECT
		MAP:
			return TYPE_OBJECT
		ARRAY:
			return TYPE_OBJECT
		SET:
			return TYPE_OBJECT
		COLLECTION:
			return TYPE_OBJECT
		STRING:
			return TYPE_STRING
		NUMBER, FLOAT32, FLOAT64:
			return TYPE_FLOAT
		BOOLEAN:
			return TYPE_BOOL
		INT8, UINT8, INT16, UINT16, INT32, UINT32, INT64, UINT64:
			return TYPE_INT
	return TYPE_NIL
