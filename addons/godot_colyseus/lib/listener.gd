extends RefCounted

const ps = preload("res://addons/godot_colyseus/lib/promises.gd")


class Callback:
	var fn: Callable
	var args
	var once = false
	
	func emit(arg: Array):
		var parmas = []
		parmas.append_array(arg)
		parmas.append_array(args)
		fn.callv(parmas)

var cbs = []

func on(fn: Callable, args: Array = []):
	var cb = Callback.new()
	cb.fn = fn
	cb.args = args
	cbs.append(cb)

func off(fn: Callable):
	var willremove = []
	for cb in cbs:
		if cb.fn == fn:
			willremove.append(cb)
	for cb in willremove:
		cbs.erase(cb)

func once(fn: Callable, args: Array = []):
	var cb = Callback.new()
	cb.fn = fn
	cb.args = args
	cb.once = true
	cbs.append(cb)

func wait() -> ps.Promise:
	var promise = ps.Promise.new()
	once(Callable(self, "_on_event"), [promise])
	return promise

func _on_event(data, promise: ps.Promise):
	promise.resolve(data)

func emit(argv: Array = []):
	var willremove = []
	var size = cbs.size()
	for i in range(size):
		var cb = cbs[i]
		if !is_instance_valid(cb):
			cbs.remove_at(i)
			i -= 1
			size -= 1
			continue
		cb.emit(argv)
		if cb.once:
			willremove.append(cb)
	for cb in willremove:
		cbs.erase(cb)
