# Copyright (C) 2019 Tintin Ho
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# godot-msgpack
#
# This is a MessagePack serializer written in pure GDSciprt. To install this
# library in your project simply and copy and paste this file inside your
# project (e.g. res://msgpack.gd).
#
#
# class Msgpack
#   static Dictionary encode(Variant value)
#     Convert a value (number, string, array and dictionary) into their
#     counterparts in messagepack. Returns dictionary with three fields:
#     `result` which is the packed data (a PackedByteArray); `error` which is the
#     error code; and `error_string` which is a human readable error message
#
#   static Dictionary decode(PackedByteArray bytes)
#     Convert a packed data (a PackedByteArray) into a value, the reverse of the
#     encode function. The return value is similar to the one in the encode
#     method

static func encode(value, buffer: StreamPeerBuffer):
	var ctx = {error = OK, error_string = ""}
	buffer.big_endian = true

	_encode(buffer, value, ctx)
	if ctx.error == OK:
		return {
			result = buffer.data_array,
			error = OK,
			error_string = "",
		}
	else:
		return {
			result = PackedByteArray(),
			error = ctx.error,
			error_string = ctx.error_string,
		}

static func decode(buffer: StreamPeerBuffer):
	buffer.big_endian = true

	var ctx = {error = OK, error_string = ""}
	var value = _decode(buffer, ctx)
	if ctx.error == OK:
		if buffer.get_position() == buffer.get_size():
			return {result = value, error = OK, error_string = ""}
		else:
			var msg = "excess buffer %s bytes" % [buffer.get_size() - buffer.get_position()]
			return {result = null, error = FAILED, error_string = msg}
	else:
		return {result = null, error = ctx.error, error_string = ctx.error_string}

static func _encode(buf, value, ctx):
	match typeof(value):
		TYPE_NIL:
			buf.put_u8(0xc0)

		TYPE_BOOL:
			if value:
				buf.put_u8(0xc3)
			else:
				buf.put_u8(0xc2)

		TYPE_INT:
			if -(1 << 5) <= value and value <= (1 << 7) - 1:
				# fixnum (positive and negative)
				buf.put_8(value)
			elif -(1 << 7) <= value and value <= (1 << 7):
				buf.put_u8(0xd0)
				buf.put_8(value)
			elif -(1 << 15) <= value and value <= (1 << 15):
				buf.put_u8(0xd1)
				buf.put_16(value)
			elif -(1 << 31) <= value and value <= (1 << 31):
				buf.put_u8(0xd2)
				buf.put_32(value)
			else:
				buf.put_u8(0xd3)
				buf.put_64(value)

		TYPE_FLOAT:
			buf.put_u8(0xcb)
			buf.put_double(value)

		TYPE_STRING:
			var bytes = value.to_utf8_buffer()

			var size = bytes.size()
			if size <= (1 << 5) - 1:
				# type fixstr [101XXXXX]
				buf.put_u8(0xa0 | size)
			elif size <= (1 << 8) - 1:
				# type str 8
				buf.put_u8(0xd9)
				buf.put_u8(size)
			elif size <= (1 << 16) - 1:
				# type str 16
				buf.put_u8(0xda)
				buf.put_u16(size)
			elif size <= (1 << 32) - 1:
				# type str 32
				buf.put_u8(0xdb)
				buf.put_u32(size)
			else:
				assert(false)

			buf.put_data(bytes)

		TYPE_PACKED_BYTE_ARRAY:
			var size = value.size()
			if size <= (1 << 8) - 1:
				buf.put_u8(0xc4)
				buf.put_u8(size)
			elif size <= (1 << 16) - 1:
				buf.put_u8(0xc5)
				buf.put_u16(size)
			elif size <= (1 << 32) - 1:
				buf.put_u8(0xc6)
				buf.put_u32(size)
			else:
				assert(false)

			buf.put_data(value)

		TYPE_ARRAY:
			var size = value.size()
			if size <= 15:
				# type fixarray [1001XXXX]
				buf.put_u8(0x90 | size)
			elif size <= (1 << 16) - 1:
				# type array 16
				buf.put_u8(0xdc)
				buf.put_u16(size)
			elif size <= (1 << 32) - 1:
				# type array 32
				buf.put_u8(0xdd)
				buf.put_u32(size)
			else:
				assert(false)

			for obj in value:
				_encode(buf, obj, ctx)
				if ctx.error != OK:
					return

		TYPE_DICTIONARY:
			var size = value.size()
			if size <= 15:
				# type fixmap [1000XXXX]
				buf.put_u8(0x80 | size)
			elif size <= (1 << 16) - 1:
				# type map 16
				buf.put_u8(0xde)
				buf.put_u16(size)
			elif size <= (1 << 32) - 1:
				# type map 32
				buf.put_u8(0xdf)
				buf.put_u32(size)
			else:
				assert(false)

			for key in value:
				_encode(buf, key, ctx)
				if ctx.error != OK:
					return

				_encode(buf, value[key], ctx)
				if ctx.error != OK:
					return
		_:
			ctx.error = FAILED
			ctx.error_string = "unsupported data type %s" % [typeof(value)]

static func _decode(buffer, ctx):
	if buffer.get_position() == buffer.get_size():
		ctx.error = FAILED
		ctx.error_string = "unexpected end of input"
		return null

	var head = buffer.get_u8()
	if head == 0xc0:
		return null
	elif head == 0xc2:
		return false
	elif head == 0xc3:
		return true

	# Integers
	elif head & 0x80 == 0:
		# positive fixnum
		return head
	elif (~head) & 0xe0 == 0:
		# negative fixnum
		return head - 256
	elif head == 0xcc:
		# uint 8
		if buffer.get_size() - buffer.get_position() < 1:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for uint8"
			return null

		return buffer.get_u8()
	elif head == 0xcd:
		# uint 16
		if buffer.get_size() - buffer.get_position() < 2:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for uint16"
			return null

		return buffer.get_u16()
	elif head == 0xce:
		# uint 32
		if buffer.get_size() - buffer.get_position() < 4:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for uint32"
			return null

		return buffer.get_u32()
	elif head == 0xcf:
		# uint 64
		if buffer.get_size() - buffer.get_position() < 8:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for uint64"
			return null

		return buffer.get_u64()
	elif head == 0xd0:
		# int 8
		if buffer.get_size() - buffer.get_position() < 1:
			ctx.error = FAILED
			ctx.error_string = "not enogh buffer for int8"
			return null

		return buffer.get_8()
	elif head == 0xd1:
		# int 16
		if buffer.get_size() - buffer.get_position() < 2:
			ctx.error = FAILED
			ctx.error_string = "not enogh buffer for int16"
			return null

		return buffer.get_16()
	elif head == 0xd2:
		# int 32
		if buffer.get_size() - buffer.get_position() < 4:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for int32"
			return null

		return buffer.get_32()
	elif head == 0xd3:
		# int 64
		if buffer.get_size() - buffer.get_position() < 8:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for int64"
			return null

		return buffer.get_64()

	# Float
	elif head == 0xca:
		# float32
		if buffer.get_size() - buffer.get_position() < 4:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for float32"
			return null

		return buffer.get_float()
	elif head == 0xcb:
		# float64
		if buffer.get_size() - buffer.get_position() < 4:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for float64"
			return null

		return buffer.get_double()

	# String
	elif (~head) & 0xa0 == 0:
		var size = head & 0x1f
		if buffer.get_size() - buffer.get_position() < size:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for fixstr required %s bytes" % [size]
			return null

		return buffer.get_utf8_string(size)
	elif head == 0xd9:
		if buffer.get_size() - buffer.get_position() < 1:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for str8 size"
			return null

		var size = buffer.get_u8()
		if buffer.get_size() - buffer.get_position() < size:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for str8 data required %s bytes" % [size]
			return null

		return buffer.get_utf8_string(size)
	elif head == 0xda:
		if buffer.get_size() - buffer.get_position() < 2:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for str16 size"
			return null

		var size = buffer.get_u16()
		if buffer.get_size() - buffer.get_position() < size:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for str16 data required %s bytes" % [size]
			return null

		return buffer.get_utf8_string(size)
	elif head == 0xdb:
		if buffer.get_size() - buffer.get_position() < 4:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for str32 size"
			return null

		var size = buffer.get_u32()
		if buffer.get_size() - buffer.get_position() < size:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for str32 data required %s bytes" % [size]
			return null

		return buffer.get_utf8_string(size)

	# Binary
	elif head == 0xc4:
		if buffer.get_size() - buffer.get_position() < 1:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for bin8 size"
			return null

		var size = buffer.get_u8()
		if buffer.get_size() - buffer.get_position() < size:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for bin8 data required %s bytes" % [size]
			return null

		var res = buffer.get_data(size)
		assert(res[0] == OK)
		return res[1]
	elif head == 0xc5:
		if buffer.get_size() - buffer.get_position() < 2:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for bin16 size"
			return null

		var size = buffer.get_u16()
		if buffer.get_size() - buffer.get_position() < size:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for bin16 data required %s bytes" % [size]
			return null

		var res = buffer.get_data(size)
		assert(res[0] == OK)
		return res[1]
	elif head == 0xc6:
		if buffer.get_size() - buffer.get_position() < 4:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for bin32 size"
			return null

		var size = buffer.get_u32()
		if buffer.get_size() - buffer.get_position() < size:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for bin32 data required %s bytes" % [size]
			return null

		var res = buffer.get_data(size)
		assert(res[0] == OK)
		return res[1]

	# Array
	elif head & 0xf0 == 0x90:
		var size = head & 0x0f
		var res = []
		for i in range(size):
			res.append(_decode(buffer, ctx))
			if ctx.error != OK:
				return null
		return res
	elif head == 0xdc:
		if buffer.get_size() - buffer.get_position() < 2:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for array16 size"
			return null

		var size = buffer.get_u16()
		var res = []
		for i in range(size):
			res.append(_decode(buffer, ctx))
			if ctx.error != OK:
				return null
		return res
	elif head == 0xdd:
		if buffer.get_size() - buffer.get_position() < 4:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for array32 size"
			return null

		var size = buffer.get_u32()
		var res = []
		for i in range(size):
			res.append(_decode(buffer, ctx))
			if ctx.error != OK:
				return null
		return res

	# Map
	elif head & 0xf0 == 0x80:
		var size = head & 0x0f
		var res = {}
		for i in range(size):
			var k = _decode(buffer, ctx)
			if ctx.error != OK:
				return null

			var v = _decode(buffer, ctx)
			if ctx.error != OK:
				return null

			res[k] = v
		return res
	elif head == 0xde:
		if buffer.get_size() - buffer.get_position() < 2:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for map16 size"
			return null

		var size = buffer.get_u16()
		var res = {}
		for i in range(size):
			var k = _decode(buffer, ctx)
			if ctx.error != OK:
				return null

			var v = _decode(buffer, ctx)
			if ctx.error != OK:
				return null

			res[k] = v
		return res
	elif head == 0xdf:
		if buffer.get_size() - buffer.get_position() < 4:
			ctx.error = FAILED
			ctx.error_string = "not enough buffer for map32 size"
			return null

		var size = buffer.get_u32()
		var res = {}
		for i in range(size):
			var k = _decode(buffer, ctx)
			if ctx.error != OK:
				return null

			var v = _decode(buffer, ctx)
			if ctx.error != OK:
				return null

			res[k] = v
		return res

	else:
		ctx.error = FAILED
		ctx.error_string = "invalid byte tag %02X at pos %s" % [head, buffer.get_position()]
		return null
