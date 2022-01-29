extends Reference

var _running = false
var fn: FuncRef
var argv: Array

# Called when the node enters the scene tree for the first time.
func _init(fn: FuncRef, argv: Array = []):
	self.fn = fn
	self.argv = argv

func start():
	if not _running:
		_running = true
		var root: SceneTree = Engine.get_main_loop()
		while true:
			yield(root, "idle_frame")
			if not _running:
				return
			fn.call_funcv(argv)

func stop():
	_running = false
