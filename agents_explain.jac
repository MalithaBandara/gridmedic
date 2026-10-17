"""Explainer (WP-B6, CLAUDE.md §8.10): why was this fault found, and why is it ranked here?

explain_fault() is the LLM call. The text is cached on the fault together with
`fault_key()`, a signature of everything the explanation depends on, so it is
recomputed only when the fault really changes (not on every priority tick).
When the LLM is unavailable, fallback_explanation() writes the same two
sentences from the fault's own evidence, so the Why? panel never stays empty.
"""

import from gm_types { Fault, FaultKind, Hazard }

def explain_fault(fault: Fault) -> str by llm();

sem explain_fault = "Explain to a control-room operator of an electricity utility, in exactly 2 short plain sentences, why this fault was identified (what the complaints showed) and why it is ranked where it is (hazard, critical loads such as a hospital or water pump, number of homes). Use only facts in the fault. If a crew report changed the diagnosis, say so. No bullet points.";
sem explain_fault.fault = "The fault, with its kind, device, evidence strings, hazard, critical loads, homes affected, priority and status.";

"""Signature of what an explanation depends on. Priority and age are left out: they move every tick."""
def fault_key(f: Fault) -> str {
    parts: list[str] = [
        f.kind.name, f.device_id, f.street, f.hazard.name, f.status.name,
        str(f.homes_affected), f"{f.confidence:.2f}",
        str(len(f.evidence)), str(len(f.critical_loads)), str(f.updated_by_crew)
    ];
    return "|".join(parts);
}

"""Two sentences built from the fault's own fields, for when the LLM is down."""
def fallback_explanation(f: Fault) -> str {
    why = f.evidence[0] if len(f.evidence) > 0 else "the complaints point to this device";
    first = f"{f.kind_label or f.kind.name} at {f.device_id}: {why}.";
    reasons: list[str] = [];
    if f.hazard != Hazard.NONE {
        reasons.append("a safety hazard was reported");
    }
    if len(f.critical_loads) > 0 {
        loads = ", ".join(f.critical_loads);
        reasons.append(f"it serves critical load ({loads})");
    }
    reasons.append(f"{f.homes_affected} homes are affected");
    second = "It is ranked here because " + " and ".join(reasons) + ".";
    if f.updated_by_crew {
        second += " A crew report corrected the original diagnosis.";
    }
    return first + " " + second;
}
