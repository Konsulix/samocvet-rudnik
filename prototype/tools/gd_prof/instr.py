# wrap every top-level func of the given .gd files with a timer (exclusive time per function)
import re, sys, os
SKIP = {"_init", "_ready", "_process", "_physics_process", "_notification", "_draw", "_input", "_gui_input", "_to_string",
        "_enter_tree", "_exit_tree", "_unhandled_input", "_get", "_set", "_has_point", "_get_minimum_size"}
SIG = re.compile(r'^(static\s+)?func\s+(\w+)\s*\((.*)\)\s*(->\s*([\w\.\[\], ]+))?\s*:\s*(#.*)?$')

def split_args(s):
    out, depth, cur, q = [], 0, "", None
    for ch in s:
        if q:
            cur += ch
            if ch == q: q = None
            continue
        if ch in "\"'":
            q = ch; cur += ch; continue
        if ch in "([{": depth += 1
        if ch in ")]}": depth -= 1
        if ch == "," and depth == 0:
            out.append(cur); cur = ""
        else:
            cur += ch
    if cur.strip(): out.append(cur)
    return out

def do(path, tag):
    src = open(path, encoding="utf-8").read().split("\n")
    # find top-level funcs and their bodies
    starts = [i for i, l in enumerate(src) if re.match(r'^(static\s+)?func\s', l)]
    out = list(src)
    add = []
    n = 0
    for si, i in enumerate(starts):
        m = SIG.match(src[i])
        if not m: continue
        static, name, args, _, ret, _c = m.groups()
        if name in SKIP: continue
        # body: until next col-0 non-empty, non-comment line
        j = i + 1
        while j < len(src) and (src[j] == "" or src[j][0] in "\t #"):
            j += 1
        body = "\n".join(src[i + 1:j])
        if re.search(r'\bawait\b', body): continue
        names = []
        for a in split_args(args):
            a = a.strip()
            nm = re.match(r'(\w+)', a).group(1)
            names.append(nm)
        out[i] = src[i].replace("func " + name, "func __p_" + name, 1)
        st = static or ""
        head = "%sfunc %s(%s)%s:" % (st, name, args, (" -> " + ret) if ret else "")
        call = "__p_%s(%s)" % (name, ", ".join(names))
        key = "%s.%s" % (tag, name)
        if ret and ret.strip() == "void":
            w = [head, "\tProf.enter()", "\t" + call, "\tProf.leave(\"%s\")" % key]
        else:
            w = [head, "\tProf.enter()", "\tvar __r = " + call, "\tProf.leave(\"%s\")" % key, "\treturn __r"]
        add += w + [""]
        n += 1
    # recursion inside the body must call the wrapper? leave as is: recursive calls go through the wrapper by name
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n\n" + "\n".join(add))
    return n

for p in sys.argv[1:]:
    tag = os.path.splitext(os.path.basename(p))[0]
    print(tag, do(p, tag))
