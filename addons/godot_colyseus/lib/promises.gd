extends RefCounted

class Promise: 
	enum State {
		Waiting,
		Success,
		Failed
	}
	var result
	
	signal completed
	
	var _state: State = State.Waiting
	
	func get_state() -> State:
		return _state
	
	func resolve(res = null):
		if res is Promise:
			await res.completed
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
	
	func get_data():
		if _state == State.Success:
			return result
		return null
	
	func get_error():
		if _state == State.Failed:
			return result
		return null
	
	func wait():
		if _state == State.Waiting:
			await self.completed
		return self

	func _to_string():
		match _state:
			State.Waiting:
				return "[Waiting]"
			State.Success:
				return str("[Success:",result,"]")
			State.Failed:
				return str("[Failed:",result,"]")
	
	func _next(promise, callback: Callable, argv: Array):
		await wait()
		if _state == State.Success:
			var arr = [get_data(), promise]
			arr.append_array(argv)
			var ret = await callback.callv(arr)
			promise.resolve(ret)
	
	func then(callback: Callable, argv: Array = []) -> Promise:
		return RunPromise.new(Callable(self, "_next"), [callback, argv])

class FramePromise extends Promise:
	var cb: Callable
	var argv: Array
	
	func _init(callback: Callable,argv: Array = []):
		cb = callback
		self.argv = argv
		_run()
	
	func _run():
		var root = Engine.get_main_loop()
		while true:
			if root is SceneTree:
				await root.process_frame
			var arr = [self]
			arr.append_array(argv)
			cb.callv(arr)
			if get_state() != State.Waiting:
				break

class RunPromise extends Promise:
	var cb: Callable
	var argv: Array
	
	func _init(callback: Callable,argv: Array = []):
		cb = callback
		self.argv = argv
		_run()
	
	func _run():
		var arr = [self]
		arr.append_array(argv)
		await cb.callv(arr)
