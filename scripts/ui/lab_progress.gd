class_name LabProgress
extends RefCounted
## Which lab experiments the student has marked as done, kept in user:// between sessions.

const PATH: String = "user://lab_progress.cfg"

static var _config: ConfigFile


static func is_done(lab: int) -> bool:
	return _load().get_value("done", str(lab), false)


static func set_done(lab: int, done: bool) -> void:
	_load().set_value("done", str(lab), done)
	_config.save(PATH)


static func done_count(labs: PackedInt32Array) -> int:
	var n: int = 0
	for lab: int in labs:
		if is_done(lab):
			n += 1
	return n


static func _load() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(PATH)  # missing on first run: starts empty
	return _config
