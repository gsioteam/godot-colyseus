extends Reference

class Promise: 
	enum State {
		Waiting,
		Success,
		Failed
	}
	var result
	
	signal completed
	
	var _state: int = State.Waiting
	
	func get_state():
		return _state
	
	func resolve(res = null):
		if res is Promise:
			yield(res, "completed")
			result = res.result
			_state = res.get_state()
			emit_signal("completed")
		else:
			result = res
			_state = State.Success
			emit_signal("completed")
	
	func reject(error = null):
		result = error
		_state = State.Failed
		emit_signal("completed")
	
	func get_result():
		if _state == State.Success:
			return result
		return null
	
	func get_error():
		if _state == State.Failed:
			return result
		return null
	
	func await():
		if _state == State.Waiting:
			yield(self, "completed")
		else:
			yield(Engine.get_main_loop(), "idle_frame")
		return self

	func _to_string():
		match _state:
			State.Waiting:
				return "[Waiting]"
			State.Success:
				return str("[Success:",result,"]")
			State.Failed:
				return str("[Failed:",result,"]")
	
	func _next(promise, callback: FuncRef, argv: Array):
		yield(await(), "completed")
		if _state == State.Success:
			var arr = [get_result(), promise]
			arr.append_array(argv)
			var ret = callback.call_funcv(arr)
			if ret is GDScriptFunctionState:
				ret = yield(ret, "completed")
			promise.resolve(ret)
	
	func then(var callback: FuncRef, var argv: Array = []) -> Promise:
		return RunPromise.new(funcref(self, "_next"), [callback, argv])

class FramePromise extends Promise:
	var cb: FuncRef
	var argv: Array
	
	func _init(var callback: FuncRef, var argv: Array = []):
		cb = callback
		self.argv = argv
		_run()
	
	func _run():
		var root = Engine.get_main_loop()
		while true:
			if root is SceneTree:
				yield(root, "idle_frame")
			var arr = [self]
			arr.append_array(argv)
			cb.call_funcv(arr)
			if get_state() != State.Waiting:
				break

class RunPromise extends Promise:
	var cb: FuncRef
	var argv: Array
	
	func _init(var callback: FuncRef, var argv: Array = []):
		cb = callback
		self.argv = argv
		_run()
	
	func _run():
		var arr = [self]
		arr.append_array(argv)
		cb.call_funcv(arr)
