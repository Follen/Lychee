"""Offline 64-bit Lua 5.1, high resolution elapsed timing, sequential datasets."""
import os
import json
import pathlib
import statistics
import struct
import sys
import time

root = pathlib.Path(__file__).resolve().parent
project = root.parents[2]
os.chdir(project)
sys.path.insert(0, str(project / "analyze" / "tools" / "python"))
from lupa.lua51 import LuaRuntime

datasets = [int(v) for v in sys.argv[1:]] or [287, 1500]
output = {"environment": {"lua": "Lua 5.1", "bits": struct.calcsize('P') * 8,
                          "timer": "Python time.perf_counter via Lupa", "game": False}, "datasets": []}
for mounts in datasets:
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().arg = runtime.table_from([mounts, 11])
    runtime.globals().BENCH_CLOCK_MS = lambda: time.perf_counter() * 1000
    lines = []
    def capture(*args):
        line = "\t".join(str(x) for x in args)
        lines.append(line)
        if "build_ms" in line:
            print(line, flush=True)
    runtime.globals().print = capture
    # Validated finite workload (<=21 rounds, <=1500 mounts), no instruction
    # hook during timing: hook dispatch changes the measured interpreter cost.
    runtime.eval("dofile")((root / "measure.lua").as_posix())
    data = {"mounts": mounts, "normal": {}, "load": {}, "memory": {}, "profile": {}, "meta": {}, "checks": []}
    for line in lines:
        if line.startswith("MEASURE\t"):
            _, stage, round_, key, value = line.split("\t")
            bucket = data[stage].setdefault(round_, {}) if stage == "normal" else data[stage]
            bucket[key] = float(value)
        else:
            data["checks"].append(line)
    data["summary_rebuild_10"] = {}
    samples = [values for n, values in data["normal"].items() if n != "1"]
    for key in samples[0]:
        values = [sample[key] for sample in samples]
        data["summary_rebuild_10"][key] = {"min": min(values), "median": statistics.median(values), "max": max(values)}
    output["datasets"].append(data)
    print(json.dumps({"mounts": mounts, "first": data["normal"]["1"], "rebuild10": data["summary_rebuild_10"],
                      "memory": data["memory"], "profile": data["profile"], "checks": data["checks"]}, ensure_ascii=False), flush=True)
    del runtime
target = root / "results-rerun-x64.json"
target.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
print(target, flush=True)
