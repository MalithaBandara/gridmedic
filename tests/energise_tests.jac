"""Acceptance tests for Energiser (WP-C3, PLAN.md §5 WP-C3)."""

import from grid {
    GridNode,
    Substation,
    Section,
    Switch,
    Transformer,
    Home,
    Energiser,
    children
}
import from grid_build { build_grid, reset_grid }
import from grid_storm { apply_storm_truth }

def _all_homes(ss: Substation) -> list[Home] {
    seen: set[str] = set();
    homes: list[Home] = [];
    q: list[GridNode] = [ss];
    while q {
        curr = q.pop(0);
        if curr.id in seen {
            continue;
        }
        seen.add(curr.id);
        if isinstance(curr, Home) {
            homes.append(curr as Home);
        }
        q.extend(children(curr));
    }
    return homes;
}

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
        q.extend(children(curr));
    }
    return res;
}

test "normal grid has all 600 homes powered and sections energised" {
    reset_grid();
    ss = build_grid();
    ss spawn Energiser();
    nodes = _by_id(ss);
    assert nodes["F1-A"].energised;
    assert nodes["F1-B"].energised;
    assert nodes["F1-C"].energised;
    assert nodes["F2-A"].energised;
    assert nodes["F2-B"].energised;
    homes = _all_homes(ss);
    assert len(homes) == 600;
    assert all([h.has_power for h in homes]);
}

test "after apply_storm_truth, 310 consumers are off and matching sections are de-energised" {
    reset_grid();
    ss = build_grid();
    apply_storm_truth();
    ss spawn Energiser();
    nodes = _by_id(ss);

    # F1-B and F1-C are de-energised (205 homes: T3=80, T4=55, T5=70)
    assert not nodes["F1-B"].energised;
    assert not nodes["F1-C"].energised;
    assert not nodes["T3"].energised;
    assert not nodes["T4"].energised;
    assert not nodes["T5"].energised;

    # F1-A is still energised (T1=60, T2=45)
    assert nodes["F1-A"].energised;
    assert nodes["T1"].energised;
    assert nodes["T2"].energised;

    # F2: T6 fuse blown, T8 fuse blown, Lake Road under T9 down
    assert nodes["F2-A"].energised;
    assert not nodes["T6"].energised;
    assert nodes["T7"].energised;
    assert nodes["F2-B"].energised;
    assert not nodes["T8"].energised;
    assert nodes["T9"].energised;
    assert nodes["T10"].energised;

    homes = _all_homes(ss);
    off_homes = [h for h in homes if not h.has_power];
    assert len(off_homes) == 310, f"Expected 310 off, got {len(off_homes)}";

    t3_off = [h for h in homes if h.transformer_id == "T3" and not h.has_power];
    assert len(t3_off) == 80;
    t4_off = [h for h in homes if h.transformer_id == "T4" and not h.has_power];
    assert len(t4_off) == 55;
    t5_off = [h for h in homes if h.transformer_id == "T5" and not h.has_power];
    assert len(t5_off) == 70;
    t6_off = [h for h in homes if h.transformer_id == "T6" and not h.has_power];
    assert len(t6_off) == 50;
    t8_off = [h for h in homes if h.transformer_id == "T8" and not h.has_power];
    assert len(t8_off) == 40;
    t9_lake_off = [h for h in homes if h.transformer_id == "T9" and h.street == "Lake Road" and not h.has_power];
    assert len(t9_lake_off) == 15;
    t9_other_on = [h for h in homes if h.transformer_id == "T9" and h.street != "Lake Road" and h.has_power];
    assert len(t9_other_on) == 60;
}

test "closing TS1 after opening SW2 restores F1-C and T5 from Feeder 2" {
    reset_grid();
    ss = build_grid();
    apply_storm_truth();
    nodes = _by_id(ss);

    # Simulate restorer action ACT-2: open SW2, close TS1
    (nodes["SW2"] as Switch).closed = False;
    (nodes["TS1"] as Switch).closed = True;

    ss spawn Energiser();

    # F1-C and T5 are now backfed from F2 through TS1!
    assert nodes["F1-C"].energised;
    assert nodes["T5"].energised;

    # F1-B is still isolated and off
    assert not nodes["F1-B"].energised;
    assert not nodes["T3"].energised;
    assert not nodes["T4"].energised;

    homes = _all_homes(ss);
    off_homes = [h for h in homes if not h.has_power];
    assert len(off_homes) == 240, f"Expected 240 off, got {len(off_homes)}";
    t5_on = [h for h in homes if h.transformer_id == "T5" and h.has_power];
    assert len(t5_on) == 70;
}
