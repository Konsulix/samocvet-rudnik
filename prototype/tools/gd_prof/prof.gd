extends Node
## exclusive time per wrapped function (main thread only)
var stack: Array = []
var acc := {}
var on := true
var main_id := 0
func _ready() -> void:
	main_id = OS.get_thread_caller_id()
func enter() -> void:
	if not on or OS.get_thread_caller_id() != main_id: return
	stack.append(Time.get_ticks_usec())
	stack.append(0)
func leave(name: String) -> void:
	if not on or OS.get_thread_caller_id() != main_id or stack.is_empty(): return
	var child: int = stack.pop_back()
	var t0: int = stack.pop_back()
	var el := Time.get_ticks_usec() - t0
	var a = acc.get(name)
	if a == null:
		a = [0, 0, 0]
		acc[name] = a
	a[0] += el - child
	a[1] += 1
	a[2] += el
	if stack.size(): stack[-1] += el
func dump(title: String, top := 45) -> void:
	var rows := []
	var sum := 0
	for k in acc:
		rows.append([acc[k][0], k, acc[k][1], acc[k][2]])
		sum += acc[k][0]
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("PROF ---- %s: %d ms in wrapped functions" % [title, sum / 1000])
	for r in rows.slice(0, top):
		print("PROF %7.1f ms self  %5.1f%%  %8d calls  %7.1f ms incl  %s" % [r[0] / 1000.0, 100.0 * r[0] / maxf(1.0, sum), r[2], r[3] / 1000.0, r[1]])
	acc.clear()
