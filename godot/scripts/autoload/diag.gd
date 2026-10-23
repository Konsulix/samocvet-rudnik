extends Node
## Diagnostics you can read on the phone itself: engine and script errors (from any thread), frames that
## took too long and what was running at the time, and how long each specimen build took.
## Hold the ♪ button for a second to open it; Copy puts the whole log on the clipboard to paste into a chat.

const MAX := 160
const SLOW_MS := 60

var _lines := PackedStringArray()
var _lock := Mutex.new()
var _active := {}     # what is running now: name -> start ms
var _logger: ErrLog

class ErrLog extends Logger:
	var diag: Node
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
		diag.note("%s %s (%s:%d %s)" % [kind, rationale if rationale != "" else code, file.get_file(), line, function])
	func _log_message(_message: String, _error: bool) -> void:
		pass

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_logger = ErrLog.new()
	_logger.diag = self
	OS.add_logger(_logger)
	note("start: %s, %s, %d cores" % [OS.get_model_name(), RenderingServer.get_video_adapter_name(), OS.get_processor_count()])

## add a line (safe from any thread)
func note(s: String) -> void:
	_lock.lock()
	_lines.append("%6.2f  %s" % [Time.get_ticks_msec() / 1000.0, s])
	if _lines.size() > MAX:
		_lines = _lines.slice(_lines.size() - MAX)
	_lock.unlock()

func begin(job: String) -> void:
	_lock.lock()
	_active[job] = Time.get_ticks_msec()
	_lock.unlock()

func end(job: String, ok := true) -> void:
	_lock.lock()
	var t0: int = _active.get(job, Time.get_ticks_msec())
	_active.erase(job)
	_lock.unlock()
	note("%s %s in %d ms" % [job, "done" if ok else "FAILED", Time.get_ticks_msec() - t0])

func _process(dt: float) -> void:
	var ms := int(dt * 1000.0)
	if ms >= SLOW_MS:
		_lock.lock()
		var jobs := ", ".join(PackedStringArray(_active.keys()))
		_lock.unlock()
		note("slow frame %d ms%s" % [ms, (" during: " + jobs) if jobs != "" else ""])

func text() -> String:
	_lock.lock()
	var t := "\n".join(_lines)
	_lock.unlock()
	return t

## the log in a card: scrollable, with Copy
func show_card() -> void:
	var v := Ov.card(360)
	v.add_child(UI.title("Diagnostics", 20))
	var sc := UI.scroller()
	sc.custom_minimum_size = Vector2(0, 480)
	var l := UI.label(text(), 10, UI.body, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(l)
	v.add_child(sc)
	sc.ready.connect(func(): sc.scroll_vertical = 1 << 20)
	var copy := UI.button("Copy", "ghost_gold", 15)
	var close := UI.button("Close", "glass", 15)
	v.add_child(Reveal.action_row(copy, func():
		DisplayServer.clipboard_set(text())
		Ov.toast("Copied"), close, func(): Ov.close()))
