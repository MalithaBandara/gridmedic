"""WP-B5 unit tests: report routing and the CrewFinding -> FaultUpdate copy.
The full crew-report flow (walker, physical truth, events) is in sim.test.jac."""

import agents_feedback;
import from byllm.lib { MockLLM }

def _f(fid: str, kind: FaultKind, device: str, street: str = "", status: FaultStatus = FaultStatus.SUSPECTED) -> Fault {
    return Fault(id=fid, kind=kind, device_id=device, homes_affected=10, street=street, status=status);
}

def _faults -> list[Fault] {
    return [
        _f("F1", FaultKind.LINE_DOWN, "F1-B"),
        _f("F2", FaultKind.TX_FUSE, "T1"),
        _f("F3", FaultKind.TX_FUSE, "T10"),
        _f("F4", FaultKind.SERVICE_WIRE, "T9", "Lake Road"),
        _f("F5", FaultKind.TX_FUSE, "T8", "", FaultStatus.RESTORED)
    ];
}

test "a crew's assigned task wins over the text" {
    assert pick_fault("F3", "T9 is fine", _faults()) == "F3";
}

test "the text names a device with exact boundaries" {
    assert pick_fault("", "T10 fuse blown, replaced", _faults()) == "F3";
    assert pick_fault("", "t1 fuse blown", _faults()) == "F2";
    assert pick_fault("", "T9 transformer is fine, fuses OK", _faults()) == "F4";
}

test "a named street or landmark section finds the fault" {
    assert pick_fault("", "line down on lake road", _faults()) == "F4";
    assert pick_fault("", "Conductor snapped at pole 23", _faults(), "F1-B") == "F1";
}

test "finished faults and unmatched text give no fault" {
    assert pick_fault("", "T8 fuse replaced", _faults()) == "";
    assert pick_fault("", "something happened somewhere", _faults()) == "";
}

test "the LLM twin is copied into the shared FaultUpdate" {
    agents_feedback.llm = MockLLM(model_name="mockllm", config={"outputs": [
        CrewFinding(fault_id="F4", device_ok=True, new_kind=FaultKind.SERVICE_WIRE, street="Lake Road", note="Service line down")
    ]});
    f = _f("F4", FaultKind.TX_FUSE, "T9");
    found = parse_crew_report("T9 fine. Service line down on Lake Road.", f);
    u = to_fault_update(found, "F4");
    assert u.fault_id == "F4" and u.new_kind == FaultKind.SERVICE_WIRE;
    assert u.street == "Lake Road" and u.device_ok and not u.restored;
}
