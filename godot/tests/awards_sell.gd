extends Node
## awards: selling stones with a gene one by one — the niche shows the best kept, then the last sold, grey.
## Run on a copy of the save: res://tests/awards_sell.tscn -- save=awtest

func _ready() -> void:
	await get_tree().process_frame
	Awards.backfill()
	# a gene that several kept stones show
	var by: Dictionary = {}
	for s in Save.d.coll:
		for t in Awards.genes_of(s):
			if not by.has(t): by[t] = []
			by[t].append(s)
	var tag := ""
	for t in by:
		if by[t].size() >= 3 and (tag == "" or by[t].size() > by[tag].size()): tag = t
	var st: Array = by[tag]
	print("gene ", tag, ": ", st.size(), " stones kept")
	var aw := Awards.new()
	var ok := true
	# sell the cheapest first, then on: the shown stone must stay the best kept until the last goes
	st.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.value) < int(b.value))
	for i in st.size():
		var s: Dictionary = st[i]
		Save.gone(s)
		Save.d.coll.erase(s)
		Awards._kept = {}
		var sh: Array = aw._shown("g:" + tag)
		var want_id: int = int(st[st.size() - 1].id) if i < st.size() - 1 else int(s.id)
		var want_kept := i < st.size() - 1
		var good: bool = int(sh[0].id) == want_id and bool(sh[1]) == want_kept
		print("sold %d (value %d) -> shows %d, kept %s %s" % [int(s.id), int(s.value), int(sh[0].id), sh[1], "ok" if good else "WRONG"])
		ok = ok and good
	# another gene, best first: the shown one steps down, and the last sold (the cheapest) stays, grey
	var tag2 := ""
	for t in by:
		if t != tag and by[t].size() >= 3 and (tag2 == "" or by[t].size() > by[tag2].size()): tag2 = t
	var st2: Array = []
	for s in by[tag2]: if Save.d.coll.has(s): st2.append(s)
	st2.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.value) > int(b.value))
	print("gene ", tag2, ": ", st2.size(), " stones kept, selling the best first")
	for i in st2.size():
		var s: Dictionary = st2[i]
		Save.gone(s)
		Save.d.coll.erase(s)
		Awards._kept = {}
		var sh: Array = aw._shown("g:" + tag2)
		var want_id: int = int(st2[i + 1].id) if i < st2.size() - 1 else int(s.id)
		var good: bool = int(sh[0].id) == want_id and bool(sh[1]) == (i < st2.size() - 1)
		print("sold %d (value %d) -> shows %d, kept %s %s" % [int(s.id), int(s.value), int(sh[0].id), sh[1], "ok" if good else "WRONG"])
		ok = ok and good
	print("RESULT ", "PASS" if ok else "FAIL")
	aw.free()
	get_tree().quit()
