"""Acceptance run (CLAUDE.md §11): a full storm through sim, then the F4 crew report.

No live LLM: the ParseCache is preloaded with what a correct model would return
for each distinct free text (keyword rules for hazards and the pole 23 landmark),
so the checks that need hazards run offline and prove no LLM call is made.
Run after `jac clean --all --force`.
"""

import agents_parse;
import agents_feedback;
import from byllm.lib { MockLLM }
import from agents_parse { LlmParsed }
import from agents_feedback { CrewFinding }
import from gm_types { Hazard, Lang, FaultKind, FaultStatus }
import from grid_storm { generate_complaints }
import from gm_types { ParsedText }
import from sim { event_log, storm_start, storm_tick, ranked_faults, apply_crew_report, counters, complaint_log }

def _preload {
    entries: dict[str, ParsedText] = {};
    for c in generate_complaints(17) {
        if c.text.startswith("BD") {
            continue;
        }
        low = c.text.lower();
        haz = Hazard.NONE;
        if "spark" in low or "ගිනි පුපුරු" in low {
            haz = Hazard.SPARKS;
        } elif "wire" in low or "වයර" in low {
            haz = Hazard.WIRE_DOWN;
        }
        lm = "pole 23" if ("pole" in low or "කණුව" in low) else "";
        entries[agents_parse._cache_key(c.text)] = ParsedText(index=0, lang=Lang.EN, hazard=haz, landmark=lm);
    }
    agents_parse._cache().entries = entries;
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    agents_parse.reset_parse_stats();
}

def _find(kind: FaultKind, device: str) -> any {
    for f in ranked_faults() {
        if f.kind == kind and f.device_id == device {
            return f;
        }
    }
    return None;
}

test "full storm finds F1-F4 ranked, then the crew report corrects F4" {
    _preload();
    storm_start(5);
    for _ in range(42) {
        storm_tick(0.5);
    }
    print("EVENTS", [e.text for e in event_log().events if e.kind == "parse_failed"][:2], len([c for c in complaint_log().items if c.hazard != Hazard.NONE]));
    hz: dict[str, int] = {};
    for c in complaint_log().items {
        hz[c.hazard.name + ("/dup" if c.is_duplicate else "")] = hz.get(c.hazard.name + ("/dup" if c.is_duplicate else ""), 0) + 1;
    }
    seen: dict[str, str] = {};
    for c in complaint_log().items {
        if not c.text.startswith("BD") {
            seen[c.text] = c.hazard.name + "/" + c.landmark;
        }
    }
    fs = ranked_faults();
    print("EV", fs[0].evidence);
    print("FAULTS", [(f.id, f.kind.name, f.device_id, f.homes_affected, f.hazard.name, f.priority, f.confidence) for f in fs]);
    assert len(fs) == 4;
    f1 = _find(FaultKind.LINE_DOWN, "F1-B");
    assert f1 is not None and f1.homes_affected == 205 and f1.hazard != Hazard.NONE;
    assert "HOSPITAL" in f1.critical_loads;
    f2 = _find(FaultKind.TX_FUSE, "T8");
    assert f2 is not None and f2.homes_affected == 40;
    f3 = _find(FaultKind.TX_FUSE, "T6");
    assert f3 is not None and f3.homes_affected == 50 and "WATER_PUMP" in f3.critical_loads;
    f4 = _find(FaultKind.TX_FUSE, "T9");
    assert f4 is not None and f4.confidence < 0.6;
    assert [f.device_id for f in fs][:2] == ["F1-B", "T6"];
    assert agents_parse.LLM_CALLS == 0;
    print("COUNTERS", counters());
    agents_feedback.llm = MockLLM(model_name="mockllm", config={"outputs": [
        CrewFinding(fault_id=f4.id, device_ok=True, new_kind=FaultKind.SERVICE_WIRE, street="Lake Road", note="service line down")
    ]});
    after = apply_crew_report("C", "T9 transformer is fine, fuses OK. Other streets have power. Overhead service line down on Lake Road.");
    assert after.kind == FaultKind.SERVICE_WIRE and after.street == "Lake Road";
    assert after.homes_affected == 15 and after.confidence >= 0.8;
    again = ranked_faults();
    assert len(again) == 4;
    assert _find(FaultKind.TX_FUSE, "T9") is None;
}
