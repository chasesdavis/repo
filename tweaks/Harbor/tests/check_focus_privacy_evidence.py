#!/usr/bin/env python3
"""Validate the recorded HID run; does not launch or call system Focus APIs."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "docs/beta7"
checks = []
def read(name):
    return json.loads((root / (name + ".json")).read_text())
def check(condition, name):
    checks.append({"name": name, "passed": bool(condition)})
def calls(data):
    return tuple(data["readerCalls"][key] for key in ("state", "modes", "registrations"))
def off(data):
    return not data["library"]["automaticFocus"] and data["library"]["focusOptInVersion"] == 0

for name in ("01-legacy-off", "02-editor-off", "03-diagnostics-off", "04-unsaved-on", "05-cancelled-on", "06-manual-work", "07-before-optin-save"):
    data = read(name)
    check(calls(data) == (0, 0, 0) and not data["monitorCreated"] and off(data), name + ": no reader created or called")
check(read("04-unsaved-on")["draft"]["automaticFocus"], "On draft was actually on, while saved access stayed off")
check(not read("05-cancelled-on")["editing"], "Cancel closed the unsaved opt-in")
check(read("06-manual-work")["displayedProfile"]["id"] == "work", "Manual profile selection changed the displayed layout without Focus")
on = read("08-saved-on")
check(on["library"]["automaticFocus"] and on["library"]["focusOptInVersion"] == 1 and calls(on) == (2, 1, 1), "Save authorized the initial read, catalog and observer registration")
pause = read("09-paused-off")
check(pause["pausedForEditor"] and not pause["draft"]["automaticFocus"] and pause["library"]["automaticFocus"] and calls(pause) == calls(on), "Off draft paused immediately before Save")
check(pause["readerCalls"]["cancellations"] == 1 and pause["readerCalls"]["removals"] == 1, "Pause canceled pending work and requested listener cleanup")
check(calls(read("10-paused-diagnostics")) == calls(pause), "Opening diagnostics while paused did not restart reads")
resume = read("11-cancel-off-restores-consent")
check(resume["library"]["automaticFocus"] and not resume["pausedForEditor"] and calls(resume) == (4, 2, 2), "Cancel restored the explicitly saved opt-in")
saved = read("12-saved-off")
check(off(saved) and calls(saved) == calls(resume), "Saving Off persisted disabled access without starting requests")
check(saved["readerCalls"]["cancellations"] == 2 and saved["readerCalls"]["removals"] == 2, "Second disable canceled work and cleaned up its listener")
check(off(read("13-reopened-diagnostics-off")) and calls(read("13-reopened-diagnostics-off")) == calls(saved), "Reopened editor and diagnostics left access disabled")
native = read("14-native-focus-handoff-gesture")
check(native["nativeRequested"] and native["lastExpanded"] == "com.apple.FocusUIModule" and not any(native["actions"].values()), "Native Focus shortcut expanded only the fixture module, with zero toggle actions")
check(calls(read("14-native-focus-handoff")) == calls(saved), "Native handoff did not start Harbor Focus reads")
fresh = read("15-relaunch-off")
check(off(fresh) and calls(fresh) == (0, 0, 0) and not fresh["monitorCreated"] and fresh["displayedProfile"]["id"] == "work", "App relaunch kept the manual profile and created no Focus reader")
report = {"scope": "Actual simulator HID interactions and shipping UIKit logic with Harbor's reader methods replaced by counted fixtures. No real Focus service or setting used.", "checks": checks, "passed": sum(c["passed"] for c in checks), "failed": sum(not c["passed"] for c in checks)}
(root / "interaction-checks.json").write_text(json.dumps(report, indent=2) + "\n")
print(f'{report["passed"]} Focus privacy interaction checks passed; {report["failed"]} failed')
raise SystemExit(bool(report["failed"]))
