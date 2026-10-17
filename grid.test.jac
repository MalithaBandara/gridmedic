import from gm_types { Crew, CrewStatus, Fault, FaultKind }
import from grid {
    GridNode,
    Substation,
    Section,
    Switch,
    Transformer,
    Home,
    CrewNode,
    FaultNode,
    SafetyCheck,
    Energiser,
    Feeds,
    children
}

test "grid declarations load and typed Feeds traverse upstream" {
    ss = Substation(id="SS1_temp", name="Moratuwa Grid Substation", x=200, y=300);
    sec = Section(id="F1-A_temp", feeder="F1", x=350, y=150);
    tx = Transformer(id="T1_temp", homes=60, feeder="F1", x=320, y=90);
    h = Home(id="H-T1-001_temp", consumer_no="4512100001", street="Main Street", transformer_id="T1_temp");
    ss +>:Feeds(capacity=700):+> sec;
    sec +>:Feeds:+> tx;
    tx +>:Feeds:+> h;
    up = [h <-:Feeds:<-];
    assert len(up) == 1 and up[0].id == "T1_temp";
    assert tx.service_ok == {};
}

test "operational nodes hold shared objs" {
    c = CrewNode(crew=Crew(id="CREW-A", depot_id="CSC-North", location_id="CSC-North", status=CrewStatus.IDLE));
    f = FaultNode(fault=Fault(id="FLT-001", kind=FaultKind.TX_FUSE, device_id="T8", homes_affected=40));
    assert f.fault.device_id == "T8";
    assert c.crew.id == "CREW-A";
}

test "safety gate stops a flagged walker" {
    sw = Switch(id="SW1", kind="recloser");
    nxt = Section(id="F1-B");
    sw +>:Feeds:+> nxt;
    w = SafetyCheck(blocked_by="SW1");
    sw spawn w;
    assert w.blocked_by == "SW1";
}

test "energiser runs on a local grid branch" {
    ss = Substation(id="SS_loc", name="Sub");
    s1 = Section(id="SEC1", line_ok=True);
    sw = Switch(id="SW_loc", closed=True);
    s2 = Section(id="SEC2", line_ok=True);
    t = Transformer(id="T_loc", fuse_ok=True, service_ok={"Main": True, "Broken": False});
    h1 = Home(id="H1", street="Main", transformer_id="T_loc");
    h2 = Home(id="H2", street="Broken", transformer_id="T_loc");

    ss +>:Feeds:+> s1;
    s1 +>:Feeds:+> sw;
    sw +>:Feeds:+> s2;
    s2 +>:Feeds:+> t;
    t +>:Feeds:+> h1;
    t +>:Feeds:+> h2;

    ss spawn Energiser();

    assert ss.energised;
    assert s1.energised;
    assert sw.energised;
    assert s2.energised;
    assert t.energised;
    assert h1.has_power;
    assert not h2.has_power;
}
