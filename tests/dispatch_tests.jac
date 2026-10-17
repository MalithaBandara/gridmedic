"""Tests for Dispatcher (WP-C4, PLAN.md §5 WP-C4, CLAUDE.md §8.5 & Test 14)."""

import from gm_types {
    CrewStatus,
    FaultStatus,
    FaultKind,
    Hazard,
    Fault
}
import from grid {
    GridNode,
    Substation,
    Section,
    CrewNode,
    FaultNode,
    Dispatcher
}
import from grid_build { build_grid, reset_grid }

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

test "test 14: first task dispatches nearest idle crew from CSC-North to F1 with ETA 8" {
    reset_grid();
    ss = build_grid();

    # Create ranked faults: F1 (F1-B, priority 1500), F3 (T6, priority 500), F2 (T8, priority 40)
    f1 = Fault(id="FLT-001", kind=FaultKind.LINE_DOWN, device_id="F1-B", homes_affected=205, priority=1500, hazard=Hazard.WIRE_DOWN);
    f3 = Fault(id="FLT-002", kind=FaultKind.TX_FUSE, device_id="T6", homes_affected=50, priority=500, critical_loads=["WATER_PUMP"]);
    f2 = Fault(id="FLT-003", kind=FaultKind.TX_FUSE, device_id="T8", homes_affected=40, priority=40);

    root ++> FaultNode(fault=f1);
    root ++> FaultNode(fault=f3);
    root ++> FaultNode(fault=f2);

    # Run dispatcher at clock 0.0
    root spawn Dispatcher(clock_min=0.0, minutes=0.0);

    crews_by_id = {cn.crew.id: cn.crew for cn in [root -->[?:CrewNode]]};

    # F1 (highest priority, Area North) assigned to nearest idle crew (Crew A at CSC-North)
    assert f1.crew_id in ["CREW-A", "CREW-B"], f"F1 crew: {f1.crew_id}";
    assert f1.eta_min == 8, f"F1 eta: {f1.eta_min}";
    assert f1.status == FaultStatus.CREW_ASSIGNED;

    c_f1 = crews_by_id[f1.crew_id];
    assert c_f1.status == CrewStatus.TRAVELLING;
    assert c_f1.task_fault_id == "FLT-001";
    assert c_f1.eta_min == 8;

    # F3 (Area South, T6) assigned to Crew C at CSC-South (travel time 8)
    assert f3.crew_id == "CREW-C", f"F3 crew: {f3.crew_id}";
    assert f3.eta_min == 8, f"F3 eta: {f3.eta_min}";
    assert crews_by_id["CREW-C"].status == CrewStatus.TRAVELLING;

    # Advance clock to 4.0 minutes (halfway)
    initial_x = c_f1.x;
    root spawn Dispatcher(clock_min=4.0, minutes=4.0);
    assert c_f1.status == CrewStatus.TRAVELLING;
    assert c_f1.eta_min == 4;
    assert c_f1.x > initial_x; # moving towards F1-B (x=550)

    # Advance clock to 8.0 minutes (arrival)
    root spawn Dispatcher(clock_min=8.0, minutes=4.0);
    assert c_f1.status == CrewStatus.ON_SITE;
    assert c_f1.eta_min == 0;
    assert c_f1.location_id == "F1-B";
    assert f1.status == FaultStatus.CONFIRMED;

    # Check work_zone is marked on section F1-B
    nodes = _by_id(ss);
    sec_f1b = nodes["F1-B"] as Section;
    assert sec_f1b.work_zone;
}
