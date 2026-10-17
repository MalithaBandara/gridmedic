test "fault labels fill from enums" {
    f = label_fault(
        Fault(id="FLT-001", kind=FaultKind.LINE_DOWN, device_id="F1-B", homes_affected=205, hazard=Hazard.WIRE_DOWN)
    );
    assert f.kind_label == "Line down";
    assert f.hazard_label == "Wire down";
    assert f.status_label == "Suspected";
    assert f.critical_loads == [];
}

test "defaults are not shared between instances" {
    a = Fault(id="a", kind=FaultKind.TX_FUSE, device_id="T8", homes_affected=40);
    b = Fault(id="b", kind=FaultKind.TX_FUSE, device_id="T6", homes_affected=50);
    a.evidence.append("x");
    assert b.evidence == [];
}

test "crew and complaint labels" {
    c = label_crew(Crew(id="CREW-A", depot_id="CSC-North", location_id="CSC-North", status=CrewStatus.IDLE));
    assert c.status_label == "Idle";
    k = label_complaint(Complaint(id="C0001", text="sparks", time_min=1.0, hazard=Hazard.SPARKS));
    assert k.hazard_label == "Sparks";
}
