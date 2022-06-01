extends Reference

const ps = preload("res://addons/godot_colyseus/lib/promises.gd")


class Callback:
	var fn: FuncRef
	var args
	var once = false
	
	func emit(arg: Array):
		var parmas = []
		parmas.append_array(arg)
		parmas.append_array(args)
		fn.call_funcv(parmas)

var cbs = []

func on(fn: FuncRef, args: Array = []):
	var cb = Callback.new()
	cb.fn = fn
	cb.args = args
	cbs.append(cb)

func off(fn: FuncRef):
	var willremove = []
	for cb in cbs:
		if cb.fn == fn:
			willremove.append(cb)
	for cb in willremove:
		cbs.erase(cb)

func once(fn: FuncRef, args: Array = []):
	var cb = Callback.new()
	cb.fn = fn
	cb.args = args
	cb.once = true
	cbs.append(cb)

func wait() -> ps.Promise:
	var promise = ps.Promise.new()
	once(funcref(self, "_on_event"), [promise])
	return promise

func _on_event(var data, promise: ps.Promise):
	promise.resolve(data)

func emit(var argv: Array = []):
	var willremove = []
	for cb in cbs:
		cb.emit(argv)
		if cb.once:
			willremove.append(cb)
	for cb in willremove:
		cbs.erase(cb)
