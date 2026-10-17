"""Field acceptance tests (WP-A3): CLAUDE.md §11 tests 6, 12 and 13.

6: a crew's T9 report changes the agent's mind (F4: T9 fuse -> Lake Road wire).
12-13: the safety check blocks closing TS1 into a crew's work zone, and the
correct plan (open SW2, then close TS1) is safe and restores T5's 70 homes.
Tests 14 and 15 are covered by tests/dispatch_tests.jac and
tests/verifier_tests.jac.

No real LLM: the parse cache holds the true parse of the hazard phrases (the
rest fall back to no hazard) and the crew report's model is a MockLLM.
    jac clean --all --force; jac test tests/field_tests.jac -v
"""

import agents_parse;
import agents_feedback;
import from byllm.lib { MockLLM }
import from agents_feedback { CrewFinding }
import from gm_types { Fault, FaultKind, FaultStatus, Hazard, Lang, ParsedText, SwitchStep }
import from grid { GridNode, Section, SafetyCheck, FaultNode, ParseCache }
import from grid_build { build_grid, reset_grid, grid_nodes }
import from grid_storm { apply_storm_truth }
import from sim { storm_start, storm_tick, ranked_faults, actions, crews }
import from api { crew_report }

glob CREW_C_T9: str = "T9 transformer is fine, fuses OK. Other streets have power. Overhead service line down on Lake Road.";

def _fault(kind: FaultKind, device: str) -> Fault | None {
    for f in ranked_faults() {
        if f.kind == kind and f.device_id == device {
            return f;
        }
    }
    return None;
}

def _node(nid: str) -> GridNode {
    return [n for n in grid_nodes(build_grid()) if n.id == nid][0];
}

def _crew_on_f1b() {
    reset_grid();
    apply_storm_truth(False);
    f1b = _node("F1-B");
    if isinstance(f1b, Section) {
        f1b.work_zone = True;
    }
}

# The storm's hazard phrases, as a correct model parses them (every other
# phrase's true parse is "no hazard", which is also the fallback). With them,
# the Pole 23 reports name F1 at once, as in a real storm.
def _preload_hazards {
    hazards: dict[str, ParsedText] = {
        "Wire fallen on the road near pole 23, sparks!": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23"),
        "Live wire hanging low near pole 23": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23"),
        "Sparks coming from the line at pole 23": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.SPARKS, landmark="pole 23"),
        "Lines down near Pole 23, whole road is dark": ParsedText(index=0, lang=Lang.EN, hazard=Hazard.WIRE_DOWN, landmark="pole 23"),
        "කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා": ParsedText(index=0, lang=Lang.SI, hazard=Hazard.WIRE_DOWN, landmark=""),
        "ගිනි පුපුරු එනවා": ParsedText(index=0, lang=Lang.SI, hazard=Hazard.SPARKS, landmark=""),
        "ට්‍රාන්ස්ෆෝමරයෙන් සද්දයක් ආවා": ParsedText(index=0, lang=Lang.SI, hazard=Hazard.TRANSFORMER_NOISE, landmark="")
    };
    found = [root -->[?:ParseCache]];
    cache = found[0] if found else (root ++> ParseCache())[0] as ParseCache;
    entries: dict[str, ParsedText] = dict(cache.entries);
    for (text, p) in hazards.items() {
        entries[agents_parse._cache_key(text)] = p;
    }
    cache.entries = entries;
}

test "6: the T9 crew's report turns F4 into a Lake Road service wire" {
    build_grid();
    _preload_hazards();
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    storm_start(5);
    for _ in range(30) {
        storm_tick(0.5);
    }
    f4 = _fault(FaultKind.TX_FUSE, "T9");
    assert f4 is not None, "F4 not suspected as a T9 fuse";
    f4_id: str = f4.id if f4 else "";
    finding = CrewFinding(fault_id=f4_id, device_ok=True, new_kind=FaultKind.SERVICE_WIRE, new_device_id="T9", street="Lake Road", note="T9 fuses OK; service line down on Lake Road");
    agents_feedback.llm = MockLLM(model_name="mockllm", config={"outputs": [finding]});
    # CLAUDE.md §6.4 has Crew C at T9, but the Dispatcher picks the crew. With
    # three crews and four faults, F4 may wait: then the crew on the lowest
    # other fault finishes (that fault is restored) and moves on to F4.
    on_f4 = [c.id for c in crews() if c.task_fault_id == f4_id];
    if not on_f4 {
        busy = [f for f in ranked_faults() if f.crew_id != "" and f.id != f4_id];
        for fn in [root -->[?:FaultNode]] {
            if fn.fault.id == busy[-1].id {
                done = fn.fault;
                done.status = FaultStatus.RESTORED;
                fn.fault = done;
            }
        }
        for _ in range(2) {
            storm_tick(0.5);
        }
        on_f4 = [c.id for c in crews() if c.task_fault_id == f4_id];
    }
    assert len(on_f4) == 1, [(f.id, f.kind_label, f.device_id, f.status_label, f.crew_id) for f in ranked_faults()];
    w = root spawn crew_report(crew_id=on_f4[0], text=CREW_C_T9);
    after: Fault = w.reports[0];
    assert after.id == f4_id, (after.id, f4_id);
    assert after.kind == FaultKind.SERVICE_WIRE, after.kind_label;
    assert after.street == "Lake Road" and after.homes_affected == 15, (after.street, after.homes_affected);
    assert after.confidence >= 0.8, after.confidence;
}

test "12: closing TS1 with SW2 closed and a crew on F1-B is blocked" {
    _crew_on_f1b();
    w = build_grid() spawn SafetyCheck(steps=[SwitchStep(switch_id="TS1", action="close")]);
    assert not w.safe, "closing TS1 should energise the F1-B work zone";
    assert "F1-B" in w.reason, w.reason;
}

test "13: open SW2 then close TS1 is safe and restores T5's 70 homes" {
    _crew_on_f1b();
    w = build_grid() spawn SafetyCheck(steps=[SwitchStep(switch_id="SW2", action="open"), SwitchStep(switch_id="TS1", action="close")]);
    assert w.safe, w.reason;
    offered = [a for a in actions() if a.safe and a.homes_restored == 70];
    assert len(offered) == 1, [(a.id, a.safe, a.homes_restored) for a in actions()];
}
