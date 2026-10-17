"""Acceptance tests for features not built yet (WP-A3): CLAUDE.md §11 tests 6, 12-15.

Kept out of tests/ so the tier-1 suite stays green. Each test names the work
package that makes it pass; move it into tests/ once it does.
    jac clean --all --force; jac test tests_pending/feature_tests.jac -v
Run the file, not `-d`: a directory run also collects the .test.jac annexes of
every imported module onto one shared root, and they pollute each other.

The storm runs with a MockLLM that has no outputs: free-text parses fall back
(no hazards), which is enough here because F1-F4 are still found by tallies.
"""

import agents_parse;
import from byllm.lib { MockLLM }
import from gm_types { Fault, FaultKind, FaultStatus, SwitchStep }
import from grid { GridNode, Section, Switch, FaultNode, SafetyCheck, Verifier, Substation }
import from grid_build { build_grid, reset_grid, grid_nodes }
import from grid_storm { apply_storm_truth, f5_followup_complaints }
import from sim { storm_start, storm_tick, ranked_faults, tasks, actions, sim_state, process_complaints, clock }
import from api { crew_report }

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

def _start {
    build_grid();
    agents_parse.llm = MockLLM(model_name="mockllm", config={"outputs": []});
    storm_start(5);
}

# Expected to fail until WP-C4 (Dispatcher).
test "14: the first task sends Crew A or B from CSC-North to F1, ETA 8" {
    _start();
    f1: Fault | None = None;
    for _ in range(12) {
        storm_tick(0.5);
        f1 = _fault(FaultKind.LINE_DOWN, "F1-B");
        if f1 {
            break;
        }
    }
    assert f1 is not None, "F1 not found within 6 minutes";
    f1_id: str = f1.id if f1 else "";
    storm_tick(0.5);
    mine = [t for t in tasks() if t.fault_id == f1_id];
    assert len(mine) == 1, [(t.crew_id, t.fault_id) for t in tasks()];
    assert mine[0].crew_id in ["CREW-A", "CREW-B"], mine[0].crew_id;
    assert mine[0].eta_min == 8, mine[0].eta_min;
}

# Expected to fail until WP-B5 (field feedback) and WP-C4 (Crew C on T9).
# B5: swap agents_feedback.llm for a MockLLM returning the CrewFinding below.
test "6: Crew C's T9 report turns F4 into a Lake Road service wire" {
    for _ in range(30) {
        storm_tick(0.5);
    }
    w = root spawn crew_report(crew_id="CREW-C", text="T9 transformer is fine, fuses OK. Other streets have power. Overhead service line down on Lake Road.");
    f4: Fault = w.reports[0];
    assert f4.kind == FaultKind.SERVICE_WIRE, f4.kind_label;
    assert f4.street == "Lake Road" and f4.homes_affected == 15, (f4.street, f4.homes_affected);
    assert f4.confidence >= 0.8, f4.confidence;
}

# Expected to fail until WP-C7 (SafetyCheck + Switch guard).
test "12: closing TS1 with SW2 closed and a crew on F1-B is blocked" {
    reset_grid();
    apply_storm_truth(False);
    f1b = _node("F1-B");
    if isinstance(f1b, Section) {
        f1b.work_zone = True;
    }
    ss = build_grid();
    w = ss spawn SafetyCheck(steps=[SwitchStep(switch_id="TS1", action="close")]);
    assert not w.safe, "closing TS1 should energise the F1-B work zone";
    assert "F1-B" in w.reason, w.reason;
}

# Expected to fail until WP-C7 (Restorer + SafetyCheck).
test "13: open SW2 then close TS1 is safe and restores T5's 70 homes" {
    reset_grid();
    apply_storm_truth(False);
    f1b = _node("F1-B");
    if isinstance(f1b, Section) {
        f1b.work_zone = True;
    }
    ss = build_grid();
    w = ss spawn SafetyCheck(steps=[SwitchStep(switch_id="SW2", action="open"), SwitchStep(switch_id="TS1", action="close")]);
    assert w.safe, w.reason;
    offered = [a for a in actions() if a.safe and a.homes_restored == 70];
    assert len(offered) == 1, [(a.id, a.safe, a.homes_restored) for a in actions()];
}

# Expected to fail until WP-B7 (Verifier).
test "15: complaints after F1's repair reveal a hidden T4 fuse" {
    sim_state().f5_enabled = True;
    _start();
    for _ in range(42) {
        storm_tick(0.5);
    }
    # Crew repairs F1: line fixed, SW1 closed, fault restored.
    f1b = _node("F1-B");
    sw1 = _node("SW1");
    if isinstance(f1b, Section) and isinstance(sw1, Switch) {
        f1b.line_ok = True;
        sw1.closed = True;
        sw1.locked_out = False;
    }
    for fn in [root -->[?:FaultNode]] {
        if fn.fault.device_id == "F1-B" {
            f = fn.fault;
            f.status = FaultStatus.RESTORED;
            fn.fault = f;
        }
    }
    process_complaints(f5_followup_complaints(clock()));
    v = root spawn Verifier(clock_min=clock() + 5.0);
    assert len(v.new_fault_ids) >= 1, "no new fault";
    t4 = _fault(FaultKind.TX_FUSE, "T4");
    assert t4 is not None;
    assert any(["complaints continued after F1 repair" in e for e in t4.evidence]), t4.evidence;
    sim_state().f5_enabled = False;
}
