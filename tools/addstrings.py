"""Appends string entries to LangEN.lua and LangES.lua.
Usage: python tools/addstrings.py file.txt   where each line is  key|english|spanish
"""
import sys, os
root = os.path.join(os.path.dirname(__file__), "..", "mod", "CryptAccess", "scripts")
rows = [l.rstrip("\n").split("|") for l in (open(0, encoding="utf-8") if sys.argv[1] == "-" else open(sys.argv[1], encoding="utf-8")) if "|" in l and not l.startswith("#")]
def esc(t): return t.replace("\\", "\\\\").replace('"', '\\"')
for col, name in ((1, "LangEN.lua"), (2, "LangES.lua")):
    p = os.path.join(root, name)
    s = open(p, encoding="utf-8").read()
    i = s.rstrip().rfind("}")
    add = []
    for r in rows:
        key = r[0]
        line = '\t["%s"] = "%s",\n' % (key, esc(r[col]))
        if '["%s"]' % key in s:
            import re
            s = re.sub(r'\t\["%s"\] = ".*?",\n' % re.escape(key), lambda m: line, s)
        else:
            add.append(line)
    s = s[:i] + "".join(add) + s[i:]
    open(p, "w", encoding="utf-8").write(s)
print(len(rows), "rows")
