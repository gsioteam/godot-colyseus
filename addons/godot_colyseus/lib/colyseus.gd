extends Object

const Client = preload("res://addons/godot_colyseus/lib/client.gd")
const Schema = preload("res://addons/godot_colyseus/lib/schema.gd")
const Room = preload("res://addons/godot_colyseus/lib/room.gd")
const types = preload("res://addons/godot_colyseus/lib/types.gd")
const Field = Schema.Field
const REF = types.REF
const MAP = types.MAP
const ARRAY = types.ARRAY
const STRING = types.STRING
const NUMBER = types.NUMBER
const BOOLEAN = types.BOOLEAN
const INT8 = types.INT8
const UINT8 = types.UINT8
const INT16 = types.INT16
const UINT16 = types.UINT16
const INT32 = types.INT32
const UINT32 = types.UINT32
const INT64 = types.INT64
const UINT64 = types.UINT64
const FLOAT32 = types.FLOAT32
const FLOAT64 = types.UINT32
const collections = preload("res://addons/godot_colyseus/lib/collections.gd")
const ArraySchema = collections.ArraySchema
const MapSchema = collections.MapSchema
const SetSchema = collections.SetSchema
const CollectionSchema = collections.CollectionSchema

const RoomInfo = preload("res://addons/godot_colyseus/lib/room_info.gd")

const Promise = preload("res://addons/godot_colyseus/lib/promises.gd").Promise
