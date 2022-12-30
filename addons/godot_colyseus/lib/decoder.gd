extends RefCounted

const MsgPack = preload("res://addons/godot_colyseus/lib/msgpack.gd")

var reader: StreamPeerBuffer

func _init(reader: StreamPeerBuffer):
	reader.big_endian = false
	self.reader = reader

func read_utf8() -> String:
	var prefix = reader.get_u8()
	var length = -1
	
	if prefix < 0xc0:
		length = prefix & 0x1f
	elif prefix == 0xd9:
		length = reader.get_u8()
	elif prefix == 0xda:
		length = reader.get_u16()
	elif prefix == 0xdb:
		length = reader.get_u32()
	
	return reader.get_string(length)

func number():
	var prefix = reader.get_u8()
	
	if prefix < 0x80:
		return prefix
	elif prefix == 0xca:
		return reader.get_float()
	elif prefix == 0xcb:
		return reader.get_double()
	elif prefix == 0xcc:
		return reader.get_u8()
	elif prefix == 0xcd:
		return reader.get_u16()
	elif prefix == 0xce:
		return reader.get_u32()
	elif prefix == 0xcf:
		return reader.get_u64()
	elif prefix == 0xd0:
		return reader.get_8()
	elif prefix == 0xd1:
		return reader.get_16()
	elif prefix == 0xd2:
		return reader.get_32()
	elif prefix == 0xd3:
		return reader.get_64()
	elif prefix > 0xdf:
		return (0xff - prefix + 1) * -1

func has_more() -> bool:
	return reader.get_position() < reader.get_size()

func current_bit() -> int:
	return reader.data_array[reader.get_position()]

func is_number() -> bool:
	var prefix = current_bit()
	return prefix < 0x80 || (prefix >= 0xca && prefix <= 0xd3)

func unpack():
	var result = MsgPack.decode(reader)
	if result.error == OK:
		return result.result
	return null
