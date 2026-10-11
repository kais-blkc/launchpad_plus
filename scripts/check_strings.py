#!/usr/bin/env python3
"""Проверяет, что во всех Resources/*.lproj одинаковый набор ключей и совпадают форматные подстановки (%d, %1$d)."""
import glob, os, re, subprocess, sys, json

def load(path):
    out = subprocess.run(["plutil", "-convert", "json", "-o", "-", path], capture_output=True, text=True)
    if out.returncode:
        sys.exit(f"{path}: {out.stderr.strip()}")
    return json.loads(out.stdout)

# launches.few/many нужны только языкам со сложным множественным числом (ru)
OPTIONAL = {"launches.few", "launches.many"}
files = sorted(glob.glob(os.path.join(os.path.dirname(__file__), "..", "Resources", "*.lproj", "Localizable.strings")))
tables = {os.path.basename(os.path.dirname(f)).removesuffix(".lproj"): load(f) for f in files}
base = tables["en"]
spec = lambda s: sorted(re.findall(r"%(?:\d+\$)?[dsf@]", s))
errors = []
for lang, t in tables.items():
    for k in base.keys() - t.keys() - OPTIONAL: errors.append(f"{lang}: нет ключа {k}")
    for k in t.keys() - base.keys() - OPTIONAL: errors.append(f"{lang}: лишний ключ {k}")
    for k, v in t.items():
        if k in base and spec(v) != spec(base[k]): errors.append(f"{lang}: {k}: подстановки {spec(v)} != {spec(base[k])}")
        if not v.strip(): errors.append(f"{lang}: {k}: пусто")
print(f"языков: {len(tables)}, ключей в en: {len(base)}")
print("\n".join(errors) if errors else "OK")
sys.exit(1 if errors else 0)
