"""WP-B2 tests: Localiser tallies and §8.2 grouping (CLAUDE.md §11 tests 1-5, 9).

No LLM: the complaints are already parsed. The fixture follows CLAUDE.md §6.1
ids and home counts; switch to grid_build.build_grid() once WP-A1 lands.
"""

import from gm_types { Complaint, Fault, FaultKind, FaultStatus, Hazard }
import from grid {
    Feeds,
    Located,
    Substation,
    Section,
    Switch,
    Transformer,
    Home,
    Landmark,
    Localiser,
    FaultNode,
    SimState
}

def _tx(sec: Section, n: int, homes: int, streets: list[str], counts: list[int], critical: list[str]) {
    tid = f"T{n}";
    t = Transformer(id=tid, homes=homes, feeder=sec.feeder, critical=critical);
    sec +>:Feeds:+> t;
    i = 1;
    for (k, street) in enumerate(streets) {
        for _j in range(counts[k]) {
            h = Home(
                id=f"H-{tid}-{i:03d}",
                consumer_no="451" + str(20 + n) + f"{i:05d}",
                street=street,
                transformer_id=tid
            );
            t +>:Feeds:+> h;
            i += 1;
        }
    }
}

def _sec(id: str, feeder: str) -> Section {
    return Section(id=id, feeder=feeder);
}

def _build {
    ss = Substation(id="SS1", name="Moratuwa Grid Substation", x=200, y=300);
    root ++> ss;
    root ++> SimState();
    f1a = _sec("F1-A", "F1");
    f1b = _sec("F1-B", "F1");
    f1c = _sec("F1-C", "F1");
    f2a = _sec("F2-A", "F2");
    f2b = _sec("F2-B", "F2");
    sw1 = Switch(id="SW1", kind="recloser");
    sw2 = Switch(id="SW2");
    sw3 = Switch(id="SW3");
    ts1 = Switch(id="TS1", kind="tie", closed=False, normally_open=True);
    ss +>:Feeds(capacity=700):+> f1a;
    f1a +>:Feeds:+> sw1;
    sw1 +>:Feeds:+> f1b;
    f1b +>:Feeds:+> sw2;
    sw2 +>:Feeds:+> f1c;
    ss +>:Feeds(capacity=700):+> f2a;
    f2a +>:Feeds:+> sw3;
    sw3 +>:Feeds:+> f2b;
    f1c +>:Feeds:+> ts1;
    f2b +>:Feeds:+> ts1;
    _tx(f1a, 1, 60, ["Galle Road", "Church Lane"], [30, 30], []);
    _tx(f1a, 2, 45, ["Galle Road", "School Lane"], [20, 25], []);
    _tx(f1b, 3, 80, ["Hospital Road", "Pole Lane"], [40, 40], ["HOSPITAL"]);
    _tx(f1b, 4, 55, ["Market Street", "Mill Road"], [30, 25], []);
    _tx(f1c, 5, 70, ["Beach Road", "Canal Road"], [35, 35], []);
    _tx(f2a, 6, 50, ["Pump House Road", "Well Lane"], [25, 25], ["WATER_PUMP"]);
    _tx(f2a, 7, 65, ["Temple Lane", "Park Road"], [35, 30], []);
    _tx(f2b, 8, 40, ["Lotus Road", "Kovil Road"], [20, 20], []);
    _tx(f2b, 9, 75, ["Lake Road", "Temple Road", "Station Road"], [15, 30, 30], []);
    _tx(f2b, 10, 60, ["Hill Street", "Rail Lane"], [30, 30], []);
    pole = Landmark(id="POLE-23", name="Pole 23", section_id="F1-B", x=560, y=150);
    pole +>:Located:+> f1b;
}

# Fresh storm state on the shared test root: build once, then clear tallies and faults.
def _fresh {
    if len([root -->[?:Substation]]) == 0 {
        _build();
    }
    idx = build_index();
    for s in idx.sections {
        s.reports = 0;
    }
    for t in idx.transformers {
        t.reports = 0;
    }
    for h in idx.homes.values() {
        h.reported = False;
    }
    for fn in [root -->[?:FaultNode]] {
        del fn;
    }
    for st in [root -->[?:SimState]] {
        st.next_fault_no = 1;
    }
}

glob _seq: int = 0;

def _c(n: int, i: int, t: float, hazard: Hazard = Hazard.NONE, landmark: str = "", dup: bool = False) -> Complaint {
    global _seq;
    _seq += 1;
    return Complaint(
        id=f"C{_seq:04d}",
        text="no power",
        time_min=t,
        consumer_no="451" + str(20 + n) + f"{i:05d}",
        home_id=f"H-T{n}-{i:03d}",
        hazard=hazard,
        landmark=landmark,
        is_duplicate=dup
    );
}

def _homes(n: int, ids: list[int], t: float) -> list[Complaint] {
    return [_c(n, i, t + 0.1 * k) for (k, i) in enumerate(ids)];
}

# F1 line down (T3, T4, T5 + Pole 23 hazards)
def _f1 -> list[Complaint] {
    global _seq;
    cs = _homes(3, list(range(4, 31)), 1.0) + _homes(4, list(range(3, 16)), 1.5) + _homes(5, list(range(1, 21)), 2.0);
    cs.append(_c(3, 1, 0.5, Hazard.WIRE_DOWN, "pole 23"));
    cs.append(_c(4, 2, 0.8, Hazard.SPARKS, "near pole 23"));
    cs.append(_c(3, 3, 0.9, Hazard.SPARKS));
    _seq += 1;
    cs.append(Complaint(id=f"C{_seq:04d}", text="wire on road near pole 23", time_min=0.6, hazard=Hazard.WIRE_DOWN, landmark="pole 23"));
    return cs;
}

def _storm -> list[Complaint] {
    cs = _f1();
    cs.extend(_homes(8, list(range(1, 15)), 3.0));                  # F2: T8 fuse, 14/40
    cs.extend(_homes(6, list(range(1, 19)), 2.5));                  # F3: T6 fuse, 18/50
    cs.extend(_homes(9, list(range(1, 9)), 4.0));                   # F4: 8 Lake Road homes
    cs.append(_c(9, 20, 5.0));                                      # ... and 1 Temple Road
    cs.extend(_homes(7, [1, 2, 3], 6.0));                           # 3 false T7 reports
    cs.append(_c(8, 1, 7.0, dup=True));                             # flagged duplicate
    cs.append(_c(6, 2, 7.5));                                       # unflagged repeat
    return cs;
}

def _find(fs: list[Fault], kind: FaultKind, device: str) -> Fault | None {
    for f in fs {
        if f.kind == kind and f.device_id == device {
            return f;
        }
    }
    return None;
}

test "localiser climbs to the substation and nodes tally" {
    _fresh();
    idx = build_index();
    h = idx.homes["H-T3-017"];
    w = h spawn Localiser(complaint_id="C9001");
    assert w.path == ["H-T3-017", "T3", "F1-B", "SW1", "F1-A", "SS1"], w.path;
    assert h.reported;
    t3 = [t for t in idx.transformers if t.id == "T3"][0];
    assert t3.reports == 1;
    assert [s.reports for s in idx.sections if s.id in ["F1-A", "F1-B"]] == [1, 1];
    # The same home again: not counted twice
    h spawn Localiser(complaint_id="C9002");
    assert t3.reports == 1;
}

test "index follows the §6.1 topology" {
    _fresh();
    idx = build_index();
    assert [s.id for s in idx.sections] == ["F1-A", "F2-A", "F1-B", "F2-B", "F1-C"];
    assert len(idx.homes) == 600;
    assert subtree_sections(idx, "F1-B") == ["F1-B", "F1-C"];
    assert landmark_section(idx, "near Pole 23!") == "F1-B";
}

test "storm complaints group into exactly F1-F4 (tests 1-5)" {
    _fresh();
    cs = _storm();
    located = localise_all(cs);
    assert located == len(cs) - 1;    # the flagged duplicate is skipped
    fs = group_faults(cs);
    assert len(fs) == 4, [f"{f.kind_label}@{f.device_id}" for f in fs];
    f1 = _find(fs, FaultKind.LINE_DOWN, "F1-B");
    assert f1 is not None;
    assert f1.homes_affected == 205;
    assert f1.hazard == Hazard.WIRE_DOWN;
    assert "HOSPITAL" in f1.critical_loads;
    assert f1.first_report_min == 0.5;
    assert len(f1.complaint_ids) == 27 + 13 + 20 + 4;
    assert any([("hazard reports mention Pole 23" in e) for e in f1.evidence]), f1.evidence;
    f2 = _find(fs, FaultKind.TX_FUSE, "T8");
    assert f2 is not None and f2.homes_affected == 40;
    f3 = _find(fs, FaultKind.TX_FUSE, "T6");
    assert f3 is not None and f3.homes_affected == 50 and "WATER_PUMP" in f3.critical_loads;
    f4 = _find(fs, FaultKind.TX_FUSE, "T9");
    assert f4 is not None and f4.confidence < 0.6 and f4.homes_affected == 75;
    assert any([("Lake Road" in e) for e in f4.evidence]), f4.evidence;
    assert sorted([f.id for f in fs]) == ["FLT-001", "FLT-002", "FLT-003", "FLT-004"];
    assert all([f.status == FaultStatus.SUSPECTED and f.kind_label != "" for f in fs]);
}

test "duplicates and repeats do not inflate tallies (test 8)" {
    _fresh();
    localise_all(_storm());
    idx = build_index();
    counts = {t.id: t.reports for t in idx.transformers};
    assert counts["T8"] == 14;
    assert counts["T6"] == 18;
    assert counts["T7"] == 3;
    assert counts["T1"] == 0;
}

test "3 false T7 reports make no fault (test 9)" {
    _fresh();
    cs = _homes(7, [1, 2, 3], 6.0);
    localise_all(cs);
    assert group_faults(cs) == [];
    assert len([root -->[?:FaultNode]]) == 0;
}

test "regrouping updates faults instead of duplicating" {
    _fresh();
    early = _homes(3, list(range(4, 31)), 1.0);
    localise_all(early);
    fs = group_faults(early);
    assert len(fs) == 1 and fs[0].kind == FaultKind.TX_FUSE and fs[0].device_id == "T3";
    first_id = fs[0].id;
    cs = early + [c for c in _storm() if not c.home_id.startswith("H-T3-") or c.home_id in ["H-T3-001", "H-T3-003"]];
    localise_all(cs);
    fs = group_faults(cs);
    assert len(fs) == 4;
    f1 = _find(fs, FaultKind.LINE_DOWN, "F1-B");
    assert f1 is not None and f1.id == first_id;    # the T3 guess grew into the line fault
    again = group_faults(cs);
    assert sorted([f.id for f in again]) == sorted([f.id for f in fs]);
}

test "a crew-corrected fault is not guessed again" {
    _fresh();
    cs = _storm();
    localise_all(cs);
    group_faults(cs);
    for fn in [root -->[?:FaultNode]] {
        if fn.fault.device_id == "T9" {
            f = fn.fault;
            f.kind = FaultKind.SERVICE_WIRE;
            f.street = "Lake Road";
            f.homes_affected = 15;
            f.confidence = 0.9;
            f.updated_by_crew = True;
            fn.fault = f;
        }
    }
    fs = group_faults(cs);
    assert len(fs) == 4;
    assert _find(fs, FaultKind.TX_FUSE, "T9") is None;
    f4 = _find(fs, FaultKind.SERVICE_WIRE, "T9");
    assert f4 is not None and f4.homes_affected == 15 and f4.confidence == 0.9;
}

test "a pole 23 hazard flags the line before the tallies do" {
    _fresh();
    cs = [c for c in _f1() if c.landmark != ""];
    localise_all(cs);
    fs = group_faults(cs);
    assert len(fs) == 1;
    assert fs[0].kind == FaultKind.LINE_DOWN and fs[0].device_id == "F1-B";
    assert fs[0].hazard == Hazard.WIRE_DOWN;
}
