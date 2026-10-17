"""Microgrid acceptance tests: MG-HOSP (hospital, on T3) and MG-RES (T5 homes).

Storm truth takes F1-B down with SW1 locked out, so T3, T4 and T5 are dark.
Starting a microgrid without opening its HV isolator must be BLOCKED; opening
the isolator first is SAFE and lights its load.
"""

import from gm_types { Action, GridNodeView }
import from sim {
    storm_start, storm_reset, apply, actions, counters, grid_view,
    run_energiser, run_restorer, drain_microgrids, sim_state
}

def _act(action_id: str) -> list[Action] {
    return [a for a in actions() if a.id == action_id];
}

def _mg(view_id: str) -> list[GridNodeView] {
    return [n for n in grid_view().nodes if n.id == view_id];
}

def _lit(view_id: str) -> bool {
    return [n for n in grid_view().nodes if n.id == view_id][0].has_power;
}

test "storm leaves the microgrid loads dark and offers blocked and safe plans" {
    storm_start(1);
    assert len(_mg("MG-HOSP")) == 1 and len(_mg("MG-RES")) == 1;
    assert not _mg("MG-HOSP")[0].supplying;
    assert not _lit("LM-HOSPITAL");
    assert counters().homes_off >= 205;
    assert _act("ACT-MG-HOSP-NOISO")[0].safe == False;
    assert "back-feed" in _act("ACT-MG-HOSP-NOISO")[0].reason;
    assert _act("ACT-MG-HOSP-START")[0].safe == True;
    assert _act("ACT-MG-RES-NOISO")[0].safe == False;
    assert _act("ACT-MG-RES-START")[0].safe == True;
}

test "an unisolated start is refused and changes nothing" {
    off: int = counters().homes_off;
    r = apply("ACT-MG-HOSP-NOISO");
    assert r.ok == False;
    assert not _mg("MG-HOSP")[0].islanded;
    assert counters().homes_off == off;
}

test "isolating then starting the hospital microgrid lights the hospital only" {
    off: int = counters().homes_off;
    r = apply("ACT-MG-HOSP-START");
    assert r.ok == True;
    mg = _mg("MG-HOSP")[0];
    assert mg.islanded and mg.isolated and mg.supplying;
    assert _lit("LM-HOSPITAL");
    assert counters().homes_off == off;    # critical_only: the 80 homes stay dark
    assert _act("ACT-MG-HOSP-NOISO") == [];
}

test "the residential microgrid restores its transformer's 70 homes" {
    off: int = counters().homes_off;
    r = apply("ACT-MG-RES-START");
    assert r.ok == True;
    assert counters().homes_off == off - 70;
    t5 = [n for n in grid_view().nodes if n.id == "T5"][0];
    assert t5.powered_by == "MG-RES";
}

test "a flat battery stops supplying and the load goes dark again" {
    off: int = counters().homes_off;
    drain_microgrids(500.0);
    run_energiser();
    assert not _mg("MG-RES")[0].supplying;
    assert not _lit("LM-HOSPITAL");
    assert counters().homes_off == off + 70;
}

test "reset restores the microgrids" {
    storm_reset();
    mg = _mg("MG-HOSP")[0];
    assert not mg.islanded and not mg.isolated and not mg.supplying;
    assert mg.battery_min == mg.battery_max;
    assert counters().homes_off == 0;
}
