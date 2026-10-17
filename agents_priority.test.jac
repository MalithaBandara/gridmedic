import from gm_types { FaultKind }

def _storm_faults -> list[Fault] {
    # Built in a deliberately wrong order; values follow CLAUDE.md §6.2.
    return [
        Fault(id="FLT-004", kind=FaultKind.TX_FUSE, device_id="T9", homes_affected=75, first_report_min=3.0, confidence=0.4),
        Fault(id="FLT-002", kind=FaultKind.TX_FUSE, device_id="T8", homes_affected=40, first_report_min=1.0),
        Fault(id="FLT-003", kind=FaultKind.TX_FUSE, device_id="T6", homes_affected=50, critical_loads=["WATER_PUMP"], first_report_min=2.0),
        Fault(id="FLT-001", kind=FaultKind.LINE_DOWN, device_id="F1-B", homes_affected=205, critical_loads=["HOSPITAL"], hazard=Hazard.WIRE_DOWN, first_report_min=0.5)
    ];
}

test "test 7: hazard first, water pump second, then by homes" {
    ranked = rank_faults(_storm_faults(), 10.0);
    assert [f.device_id for f in ranked] == ["F1-B", "T6", "T9", "T8"];
    assert ranked[0].priority == 1000 + 500 + 205 + 2 * 9;
    assert ranked[1].priority == 500 + 50 + 2 * 8;
    assert ranked[0].kind_label == "Line down";
}

test "F4 drops below T8 once the crew shrinks it to Lake Road" {
    faults = _storm_faults();
    faults[0].kind = FaultKind.SERVICE_WIRE;
    faults[0].homes_affected = 15;
    ranked = rank_faults(faults, 10.0);
    assert [f.device_id for f in ranked] == ["F1-B", "T6", "T8", "T9"];
}

test "restored faults sink to the bottom" {
    faults = _storm_faults();
    faults[3].status = FaultStatus.RESTORED;
    ranked = rank_faults(faults, 10.0);
    assert ranked[-1].device_id == "F1-B";
    assert ranked[0].device_id == "T6";
}

test "age adds 2 per minute and never goes negative" {
    f = Fault(id="X", kind=FaultKind.TX_FUSE, device_id="T1", homes_affected=60, first_report_min=5.0);
    assert priority_of(f, 2.0) == 60;
    assert priority_of(f, 15.5) == 60 + 20;
}

test "rank_fault_nodes re-scores the persisted faults" {
    for f in _storm_faults() {
        root ++> FaultNode(fault=f);
    }
    ranked = rank_fault_nodes(10.0);
    assert ranked[0].device_id == "F1-B";
    stored = [fn.fault.priority for fn in [root -->[?:FaultNode]] if fn.fault.device_id == "F1-B"];
    assert stored and stored[0] == ranked[0].priority;
}
