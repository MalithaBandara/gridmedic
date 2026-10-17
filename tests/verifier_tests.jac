"""WP-B7 acceptance (CLAUDE.md §11 test 15): the verifier finds the hidden T4 fuse after F1's repair.

No live LLM: parsing falls back (BD SMS need none) and the crew report is a MockLLM finding.
"""

import agents_parse;
import agents_feedback;
import from byllm.lib { MockLLM }
import from agents_feedback { CrewFinding }
import from gm_types { Complaint, Fault, FaultKind, FaultStatus, Hazard, Lang, ParsedText }
import from grid_storm { generate_complaints }
import from grid { FaultNode, Verifier }
import from sim { sim_state, storm_start, storm_tick, ranked_faults, apply_crew_report, event_log }

def _find(kind: FaultKind, device: str) -> Fault | None {
    for f in ranked_faults() {
        if f.kind == kind and f.device_id == device {
            return f;
        }
    }
    return None;
}

# What a correct model returns for each distinct free text (hazards, pole 23), so no LLM call is needed.
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
}

def _complaints(home_ids: list[str], t: float) -> list[Complaint] {
    return [Complaint(id=f"V{k:03d}", text="BD", time_min=t + k * 0.5, home_id=h) for (k, h) in enumerate(home_ids)];
}

def _verify(cs: list[Complaint], t0: float = 20.0) -> list[str] {
    w = Verifier(clock_min=t0 + 5.0, restored={"F1": t0}, complaints=cs);
    root spawn w;
    return w.new_fault_ids;
}

def _setup {
    storm_start(1);
    root ++> FaultNode(fault=Fault(id="F1", kind=FaultKind.LINE_DOWN, device_id="F1-B", homes_affected=205, status=FaultStatus.RESTORED));
    for fn in [root -->[?:FaultNode]] {
        if fn.fault.id.startswith("FLT") {
            del fn;
        }
    }
}

test "three distinct homes on one transformer in the window raise a TX_FUSE" {
    _setup();
    ids = _verify(_complaints(["H-T4-003", "H-T4-009", "H-T4-014"], 20.5));
    assert len(ids) == 1;
    got = _find(FaultKind.TX_FUSE, "T4");
    assert got is not None;
    f: Fault = got;
    assert f.homes_affected == 55 and f.found_by == "verifier";
    assert f.status == FaultStatus.SUSPECTED and f.id == ids[0];
    assert "complaints continued after F1-B repair" in f.evidence;
}

test "two homes, repeats, late reports and other feeders raise nothing" {
    _setup();
    assert _verify(_complaints(["H-T4-003", "H-T4-009"], 20.5)) == [];
    assert _verify(_complaints(["H-T4-003", "H-T4-003", "H-T4-003"], 20.5)) == [];    # one home repeating
    assert _verify(_complaints(["H-T4-003", "H-T4-009", "H-T4-014"], 26.0)) == [];    # after the 5 min window
    assert _verify(_complaints(["H-T4-003", "H-T4-009", "H-T4-014"], 10.0)) == [];    # before the repair
    assert _verify(_complaints(["H-T8-001", "H-T8-002", "H-T8-003"], 20.5)) == [];    # not below F1-B
    dups = _complaints(["H-T4-003", "H-T4-009", "H-T4-014"], 20.5);
    dups[2].is_duplicate = True;
    assert _verify(dups) == [];
    assert _find(FaultKind.TX_FUSE, "T4") is None;
}

test "a transformer that already has an active fault is not reported twice" {
    _setup();
    cs = _complaints(["H-T4-003", "H-T4-009", "H-T4-014"], 20.5);
    assert len(_verify(cs)) == 1;
    assert _verify(cs) == [];
}

test "full storm: after the F1 repair the T4 fuse appears and the crew-corrected faults stay" {
    _preload();
    sim_state().f5_enabled = True;
    storm_start(5);
    for _ in range(42) {
        storm_tick(0.5);
    }
    got1 = _find(FaultKind.LINE_DOWN, "F1-B");
    assert got1 is not None;
    f1: Fault = got1;
    assert _find(FaultKind.TX_FUSE, "T4") is None;
    agents_feedback.llm = MockLLM(model_name="mockllm", config={"outputs": [
        CrewFinding(fault_id=f1.id, device_ok=False, new_kind=FaultKind.LINE_DOWN, restored=True, note="Conductor repaired")
    ]});
    apply_crew_report("A", "Conductor repaired at pole 23, line restored");
    assert _find(FaultKind.TX_FUSE, "T4") is None;    # nothing yet: the follow-ups have not arrived
    for _ in range(16) {
        storm_tick(0.5);
    }
    got4 = _find(FaultKind.TX_FUSE, "T4");
    assert got4 is not None;
    t4: Fault = got4;
    assert t4.found_by == "verifier" and t4.homes_affected == 55;
    assert "complaints continued after F1-B repair" in t4.evidence;
    kinds: list[str] = [e.kind for e in event_log().events];
    assert kinds.count("verify") >= 2;
    assert len([f for f in ranked_faults() if f.device_id == "T4"]) == 1;
    storm_tick(0.5);
    assert _find(FaultKind.TX_FUSE, "T4") is not None;    # group_faults does not drop it
}
