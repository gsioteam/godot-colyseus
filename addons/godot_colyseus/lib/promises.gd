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

	func _to_string():
		match _state:
			State.Waiting:
				return "[Waiting]"
			State.Success:
				return str("[Success:",result,"]")
			State.Failed:
				return str("[Failed:",result,"]")

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
