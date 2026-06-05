extends RefCounted

var _running = false
var fn: Callable
var argv: Array

# Called when the node enters the scene tree for the first time.
func _init(fn: Callable,argv: Array = []):
	self.fn = fn
	self.argv = argv

func start():
	if not _running:
		_running = true
		var root: SceneTree = Engine.get_main_loop()
		while true:
			await root.process_frame
			if not _running:
				return
			fn.callv(argv)

func stop():
	_running = false
