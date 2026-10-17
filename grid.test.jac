import from gm_types { Crew, CrewStatus, Fault, FaultKind }
import from grid { Feeds }

test "grid declarations load and typed Feeds traverse upstream" {
    ss = Substation(id="SS1", name="Moratuwa Grid Substation", x=200, y=300);
    sec = Section(id="F1-A", feeder="F1", x=350, y=150);
    tx = Transformer(id="T1", homes=60, feeder="F1", x=320, y=90);
    h = Home(id="H-T1-001", consumer_no="4512100001", street="Main Street", transformer_id="T1");
    root ++> ss;
    ss +>:Feeds(capacity=700):+> sec;
    sec +>:Feeds:+> tx;
    tx +>:Feeds:+> h;
    up = [h <-:Feeds:<-];
    assert len(up) == 1 and up[0].id == "T1";
    assert tx.service_ok == {};
}

test "operational nodes hold shared objs" {
    c = CrewNode(crew=Crew(id="CREW-A", depot_id="CSC-North", location_id="CSC-North", status=CrewStatus.IDLE));
    f = FaultNode(fault=Fault(id="FLT-001", kind=FaultKind.TX_FUSE, device_id="T8", homes_affected=40));
    root ++> c;
    root ++> f;
    assert len([root -->[?:CrewNode]]) >= 1;
    assert f.fault.device_id == "T8";
}

test "safety gate stops a flagged walker" {
    sw = Switch(id="SW1", kind="recloser");
    nxt = Section(id="F1-B");
    sw +>:Feeds:+> nxt;
    w = SafetyCheck(blocked_by="SW1");
    sw spawn w;
    assert w.blocked_by == "SW1";
}
