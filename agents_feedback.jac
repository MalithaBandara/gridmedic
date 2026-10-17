"""Field feedback (WP-B5, CLAUDE.md §8.6): a crew's free-text report becomes a typed update.

parse_crew_report() is the only LLM call. Its output obj `CrewFinding` is declared
HERE (byllm 0.6.19 crashes on an output obj imported from another module) and
copied into the shared gm_types.FaultUpdate by to_fault_update().

pick_fault() decides which fault a report is about when the crew has no
assigned task yet (the Dispatcher lands later): the crew's task if set, else the
active fault whose device or street the text names, else the one on the section a
named landmark ("pole 23") belongs to.
"""

import re;
import from llm_switch { is_mock }
import from gm_types { Fault, FaultKind, FaultStatus, FaultUpdate }

# ------------------------------------------------------------- LLM interface
obj CrewFinding {
    has fault_id: str,
        device_ok: bool,
        new_kind: FaultKind,
        new_device_id: str = "",
        street: str = "",
        restored: bool = False,
        repair_eta_min: int = 0,
        note: str = "";
}

sem CrewFinding.fault_id = "Id of the fault the crew was sent to. Copy it from the fault given.";
sem CrewFinding.device_ok = "True if the crew found the suspected device itself healthy (e.g. 'T9 transformer is fine, fuses OK'). False if the suspected device is faulty or the report says nothing about it.";
sem CrewFinding.new_kind = "What the fault really is according to the crew. LINE_DOWN: a conductor or medium-voltage line is down or snapped. TX_FUSE: a transformer fuse is blown. SERVICE_WIRE: a low-voltage service or street wire is down on one street. Keep the fault's current kind if the crew confirms it. UNKNOWN only if the report gives no cause at all.";
sem CrewFinding.new_device_id = "Id of the device the fault is really at, such as 'T9' or 'F1-B', ONLY if it differs from the fault's current device. Empty if unchanged. 'pole 23' is on section F1-B.";
sem CrewFinding.street = "Street name the damage is on (e.g. 'Lake Road'), for a SERVICE_WIRE fault. Empty otherwise.";
sem CrewFinding.restored = "True only if the crew says supply is back or the repair is finished ('replaced', 'restored', 'pump running'). A report of damage found or work still needed is False.";
sem CrewFinding.repair_eta_min = "Minutes the crew still needs to repair it, if stated (e.g. 'needs ~90 min' = 90). 0 if not stated or already restored.";
sem CrewFinding.note = "One short sentence summing up what the crew found.";

def parse_crew_report(text: str, fault: Fault) -> CrewFinding by llm();

sem parse_crew_report = "Interpret a field crew's report about a power fault in a Sri Lankan electricity network and say what changed compared to what the control room believed.";
sem parse_crew_report.text = "The crew's free-text field report.";
sem parse_crew_report.fault = "The fault the crew was sent to, as currently believed by the control room.";

# ------------------------------------------------------------ mock interface
glob _STREET_RE: any = re.compile("(?i)\\b(?:on|at|in)\\s+([a-z]+(?:\\s[a-z]+)?\\s(?:road|lane|street|avenue|place|mawatha))");
glob _ETA_RE: any = re.compile("(?i)(\\d+)\\s*(?:min|minutes)");
glob _HEALTHY: list[str] = ["fine", "fuses ok", "fuse ok", "healthy", "intact", "no damage"];
glob _RESTORED: list[str] = ["restored", "replaced", "supply back", "supply is back", "repaired", "pump running", "back on"];

"""Offline stand-in for parse_crew_report: keyword rules over the crew's note, same fields, no Gemini."""
def mock_crew_finding(text: str, fault: Fault) -> CrewFinding {
    t: str = text.lower();
    healthy: bool = any([w in t for w in _HEALTHY]) as bool;
    service: bool = "service line" in t or "service wire" in t or "service cable" in t;
    line: bool = (not service) and (any([w in t for w in ["conductor", "line down", "lines down", "snapped", "pole"]]) as bool);
    fuse: bool = "fuse" in t and not healthy;
    restored: bool = any([w in t for w in _RESTORED]) as bool;
    kind: FaultKind = fault.kind;
    if service {
        kind = FaultKind.SERVICE_WIRE;
    } elif line {
        kind = FaultKind.LINE_DOWN;
    } elif fuse {
        kind = FaultKind.TX_FUSE;
    }
    street: str = "";
    if kind == FaultKind.SERVICE_WIRE {
        m = _STREET_RE.search(text);
        if m {
            street = str(m.group(1)).title();
        }
    }
    device: str = "";
    if kind == FaultKind.LINE_DOWN and "pole 23" in t and fault.device_id != "F1-B" {
        device = "F1-B";
    }
    eta: int = 0;
    m2 = _ETA_RE.search(text);
    if m2 and not restored {
        eta = int(str(m2.group(1)));
    }
    first: str = text.strip().split(". ")[0].strip(".") + "." if text.strip() else "";
    return CrewFinding(
        fault_id=fault.id, device_ok=healthy, new_kind=kind, new_device_id=device,
        street=street, restored=restored, repair_eta_min=eta, note=first
    );
}

"""The crew-report reader the simulation calls: the mock rules, or Gemini via parse_crew_report."""
def interpret_crew_report(text: str, fault: Fault) -> CrewFinding {
    if is_mock() {
        return mock_crew_finding(text, fault);
    }
    return parse_crew_report(text, fault);
}

# ------------------------------------------------------------------- helpers
"""Copy the LLM-facing twin into the shared type the graph and API use."""
def to_fault_update(f: CrewFinding, fault_id: str) -> FaultUpdate {
    return FaultUpdate(
        fault_id=fault_id, device_ok=f.device_ok, new_kind=f.new_kind,
        new_device_id=f.new_device_id, street=f.street, restored=f.restored,
        repair_eta_min=f.repair_eta_min, note=f.note
    );
}

def _names(text: str, word: str) -> bool {
    if word == "" {
        return False;
    }
    pat = "(?i)(?<![A-Za-z0-9-])" + re.escape(word) + "(?![A-Za-z0-9-])";
    return re.search(pat, text) is not None;
}

def _active(f: Fault) -> bool {
    return not (f.status == FaultStatus.RESTORED or f.status == FaultStatus.CLOSED);
}

"""Id of the fault a report is about, or '' if none can be told. landmark_section_id is the section a landmark in the text belongs to ('' if none)."""
def pick_fault(task_fault_id: str, text: str, faults: list[Fault], landmark_section_id: str = "") -> str {
    if task_fault_id != "" {
        for f in faults {
            if f.id == task_fault_id {
                return f.id;
            }
        }
    }
    live = [f for f in faults if _active(f)];
    # A named street is the most specific clue, then a named device.
    for f in live {
        if f.street != "" and _names(text, f.street) {
            return f.id;
        }
    }
    for f in live {
        if _names(text, f.device_id) {
            return f.id;
        }
    }
    if landmark_section_id != "" {
        for f in live {
            if f.device_id == landmark_section_id {
                return f.id;
            }
        }
    }
    return "";
}
