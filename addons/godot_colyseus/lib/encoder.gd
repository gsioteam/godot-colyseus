extends RefCounted

const MsgPack = preload("res://addons/godot_colyseus/lib/msgpack.gd")

var writer: StreamPeerBuffer

func _init(writer: StreamPeerBuffer):
	writer.big_endian = false
	self.writer = writer

func string(v: String):
	
	var bytes = v.to_utf8_buffer()
	var length = bytes.size()
	
	if length < 0x20:
		writer.put_u8(length | 0xa0)
	elif length < 0x100:
		writer.put_u8(0xd9)
		writer.put_u8(length)
	elif length < 0x10000:
		writer.put_u8(0xda)
		writer.put_u16(length)
	elif length < 0x100000000:
		writer.put_u8(0xdb)
		writer.put_u32(length)
	else:
		assert(false) #,"String too long")
	
	writer.put_data(bytes)

func number(v):
	if v == NAN:
		return number(0)
	elif v != abs(v):
		writer.put_u8(0xcb)
		writer.put_double(v)
	elif v >= 0:
		if v < 0x80:
			writer.put_u8(v)
		elif v < 0x100:
			writer.put_u8(0xcc)
			writer.put_u8(v)
		elif v < 0x10000:
			writer.put_u8(0xcd)
			writer.put_u16(v)
		elif v < 0x100000000:
			writer.put_u8(0xce)
			writer.put_u32(v)
		else:
			writer.put_u8(0xcf)
			writer.put_u32(v)
	else:
		if v >= -0x20:
			writer.put_u8(0xe0 | (v + 0x20))
		elif v >= -0x80:
			writer.put_u8(0xd0)
			writer.put_8(v)
		elif v >= -0x8000:
			writer.put_u8(0xd1)
			writer.put_16(v)
		elif v >= -0x80000000:
			writer.put_u8(0xd2)
			writer.put_32(v)
		else:
			writer.put_u8(0xd3)
			writer.put_64(v)
