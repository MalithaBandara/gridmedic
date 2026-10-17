"""Tests for SafetyCheck and Restorer (WP-C7, CLAUDE.md §8.7-8.8, Tests 12 & 13)."""

import from gm_types {
    SwitchStep,
    Action
}
import from grid {
    GridNode,
    Substation,
    Section,
    Switch,
    SafetyCheck,
    Restorer
}
import from grid_build { build_grid, reset_grid }
import from grid_storm { apply_storm_truth }

def _by_id(ss: Substation) -> dict[str, GridNode] {
    seen: set[str] = set();
    res: dict[str, GridNode] = {};
    q: list[GridNode] = [ss];
    while q {
        curr = q.pop(0);
        if curr.id in seen {
            continue;
        }
        seen.add(curr.id);
        res[curr.id] = curr;
        q.extend([x for x in [curr -->] if isinstance(x, GridNode)]);
    }
    return res;
}

test "test 12: safety check blocks closing TS1 when SW2 is closed and crew is at F1-B" {
    reset_grid();
    ss = build_grid();
    apply_storm_truth();

    nodes = _by_id(ss);
    sec_f1b = nodes["F1-B"] as Section;
    sec_f1b.work_zone = True;

    steps = [SwitchStep(switch_id="TS1", action="close")];
    sc = SafetyCheck(steps=steps);
    ss spawn sc;

    assert not sc.safe;
    assert sc.blocked_by == "TS1";
    assert "F1-B" in sc.reason;
}

test "test 13: safety check approves opening SW2 then closing TS1" {
    reset_grid();
    ss = build_grid();
    apply_storm_truth();

    nodes = _by_id(ss);
    sec_f1b = nodes["F1-B"] as Section;
    sec_f1b.work_zone = True;

    steps = [
        SwitchStep(switch_id="SW2", action="open"),
        SwitchStep(switch_id="TS1", action="close")
    ];
    sc = SafetyCheck(steps=steps);
    ss spawn sc;

    assert sc.safe;
    assert sc.blocked_by == "";
    assert sc.reason == "";
}

test "restorer generates both plans and safety check marks ACT-1 blocked and ACT-2 safe" {
    reset_grid();
    ss = build_grid();
    apply_storm_truth();

    nodes = _by_id(ss);
    sec_f1b = nodes["F1-B"] as Section;
    sec_f1b.work_zone = True;

    r = Restorer();
    root spawn r;

    assert len(r.actions) == 2;
    act1 = [a for a in r.actions if a.id == "ACT-1"][0];
    act2 = [a for a in r.actions if a.id == "ACT-2"][0];

    assert not act1.safe;
    assert "F1-B" in act1.reason;

    assert act2.safe;
    assert act2.homes_restored == 70;
}
