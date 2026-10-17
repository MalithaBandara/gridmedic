"""WP-A1 tests: the demo grid matches CLAUDE.md §6.1 and the sample-grid SOW.

Run alone after a clean, because tests share one persisted root and other
modules' fixtures also build a (partial) SS1:
    jac clean --all --force; jac test grid_build.jac
"""

import from gm_types { Crew, CrewStatus, Hazard, Lang, ParsedText }
import from grid {
    GridNode,
    Substation,
    Section,
    Switch,
    Transformer,
    Home,
    Depot,
    Landmark,
    CrewNode,
    SimState,
    ParseCache,
    children,
    parents
}
import from agents_parse { landmark_section }

def _nodes -> list[GridNode] {
    return grid_nodes(build_grid());
}

def _homes -> list[Home] {
    return [n for n in _nodes() if isinstance(n, Home)];
}

def _by_id -> dict[str, GridNode] {
    out: dict[str, GridNode] = {};
    for n in _nodes() {
        out[n.id] = n;
    }
    return out;
}

test "600 homes: 310 on F1 and 290 on F2" {
    tx_feeder: dict[str, str] = {};
    for n in _nodes() {
        if isinstance(n, Transformer) {
            tx_feeder[n.id] = n.feeder;
        }
    }
    homes = _homes();
    assert len(homes) == 600, len(homes);
    f1 = len([h for h in homes if tx_feeder[h.transformer_id] == "F1"]);
    assert f1 == 310, f1;
    assert len(homes) - f1 == 290;
}

test "home count per transformer matches its homes field and the SOW" {
    expected = {"T1": 60, "T2": 45, "T3": 80, "T4": 55, "T5": 70, "T6": 50, "T7": 65, "T8": 40, "T9": 75, "T10": 60};
    for n in _nodes() {
        if isinstance(n, Transformer) {
            got = len([h for h in children(n) if isinstance(h, Home)]);
            assert got == expected[n.id], f"{n.id}: {got}";
            assert n.homes == got;
        }
    }
}

test "T9 streets are Lake Road 15, Temple Road 30, Station Road 30" {
    counts: dict[str, int] = {};
    for h in _homes() {
        if h.transformer_id == "T9" {
            counts[h.street] = counts.get(h.street, 0) + 1;
        }
    }
    assert counts == {"Lake Road": 15, "Temple Road": 30, "Station Road": 30}, counts;
    t9 = _by_id()["T9"];
    assert isinstance(t9, Transformer) and t9.service_ok == {"Lake Road": True, "Temple Road": True, "Station Road": True};
}

test "consumer numbers are unique 10 digits and 4512300017 is a T3 home" {
    homes = _homes();
    nums = [h.consumer_no for h in homes];
    assert len(set(nums)) == 600;
    assert all([len(c) == 10 and c.isdigit() for c in nums]);
    h17 = [h for h in homes if h.consumer_no == "4512300017"];
    assert len(h17) == 1 and h17[0].id == "H-T3-017" and h17[0].transformer_id == "T3";
    assert len(set([h.id for h in homes])) == 600;
    assert consumer_no(10, 60) == "4513000060";
}

test "build_grid twice creates no duplicates" {
    before = len(_nodes());
    build_grid();
    build_grid();
    assert len([root -->[?:Substation]]) == 1;
    assert len(_nodes()) == before;
    assert len([root -->[?:CrewNode]]) == 3;
    assert len([root -->[?:Depot]]) == 2;
    assert len([root -->[?:SimState]]) == 1;
    assert len([root -->[?:ParseCache]]) == 1;
}

test "upstream walk from a T5 home reaches SS1 through SW2 and SW1" {
    h = [x for x in _homes() if x.id == "H-T5-001"][0];
    path: list[str] = [h.id];
    n: GridNode = h;
    while parents(n) {
        n = parents(n)[0];
        path.append(n.id);
    }
    assert path == ["H-T5-001", "T5", "F1-C", "SW2", "F1-B", "SW1", "F1-A", "SS1"], path;
}

test "TS1 is a normally open tie fed from F1-C and F2-B" {
    ts1 = _by_id()["TS1"];
    assert isinstance(ts1, Switch);
    assert ts1.kind == "tie" and not ts1.closed and ts1.normally_open;
    assert sorted([p.id for p in parents(ts1)]) == ["F1-C", "F2-B"];
    sw1 = _by_id()["SW1"];
    assert isinstance(sw1, Switch) and sw1.kind == "recloser" and sw1.closed;
}

test "priority loads are tagged on the right transformers" {
    expected = {"T1": ["SCHOOL"], "T3": ["HOSPITAL"], "T5": ["SCHOOL"], "T6": ["WATER_PUMP"], "T10": ["POLICE"]};
    for n in _nodes() {
        if isinstance(n, Transformer) {
            assert n.critical == expected.get(n.id, []), f"{n.id}: {n.critical}";
        }
    }
}

test "Pole 23 and the five facilities are Located on their sections" {
    want = {
        "POLE-23": "F1-B",
        "LM-HOSPITAL": "F1-B",
        "LM-PUMP": "F2-A",
        "LM-POLICE": "F2-B",
        "LM-SCHOOL-BRIDGE": "F1-C",
        "LM-SCHOOL-RAILWAY": "F1-A"
    };
    found: dict[str, str] = {};
    for n in _nodes() {
        if isinstance(n, Section) {
            for lm in [n <--] {
                if isinstance(lm, Landmark) {
                    found[lm.id] = n.id;
                    assert lm.section_id == n.id;
                }
            }
        }
    }
    assert found == want, found;
}

test "the parser maps landmark text to sections on this grid" {
    build_grid();
    assert landmark_section("Wire fallen on the road near pole 23, sparks!") == "F1-B";
    assert landmark_section("no power near Bridge Road Maha Vidyalaya") == "F1-C";
}

test "crews start idle at their depots" {
    crews: dict[str, CrewNode] = {};
    for cn in [root -->[?:CrewNode]] {
        crews[cn.crew.id] = cn;
    }
    assert sorted(crews.keys()) == ["CREW-A", "CREW-B", "CREW-C"];
    assert crews["CREW-C"].crew.depot_id == "CSC-South";
    for cn in crews.values() {
        assert cn.crew.status == CrewStatus.IDLE and cn.crew.location_id == cn.crew.depot_id;
    }
}

test "reset_grid restores the normal state and keeps the parse cache" {
    ids = _by_id();
    cache = [root -->[?:ParseCache]][0];
    cache.entries["no power"] = ParsedText(index=0, lang=Lang.EN, hazard=Hazard.NONE, landmark="");
    sw1 = ids["SW1"];
    f1b = ids["F1-B"];
    t8 = ids["T8"];
    t9 = ids["T9"];
    ts1 = ids["TS1"];
    h = ids["H-T3-017"];
    if isinstance(sw1, Switch) and isinstance(ts1, Switch) {
        sw1.closed = False;
        sw1.locked_out = True;
        ts1.closed = True;
    }
    if isinstance(f1b, Section) {
        f1b.line_ok = False;
        f1b.work_zone = True;
        f1b.reports = 9;
    }
    if isinstance(t8, Transformer) and isinstance(t9, Transformer) {
        t8.fuse_ok = False;
        t9.service_ok = {"Lake Road": False, "Temple Road": True, "Station Road": True};
    }
    if isinstance(h, Home) {
        h.reported = True;
        h.has_power = False;
    }
    for cn in [root -->[?:CrewNode]] {
        if cn.crew.id == "CREW-A" {
            cn.crew = Crew(id="CREW-A", depot_id="CSC-North", location_id="F1-B", status=CrewStatus.ON_SITE, task_fault_id="FLT-001");
        }
    }

    reset_grid();

    assert isinstance(sw1, Switch) and sw1.closed and not sw1.locked_out;
    assert isinstance(ts1, Switch) and not ts1.closed;
    assert isinstance(f1b, Section) and f1b.line_ok and not f1b.work_zone and f1b.reports == 0;
    assert isinstance(t8, Transformer) and t8.fuse_ok;
    assert isinstance(t9, Transformer) and t9.service_ok["Lake Road"];
    assert isinstance(h, Home) and h.has_power and not h.reported;
    a = [cn for cn in [root -->[?:CrewNode]] if cn.crew.id == "CREW-A"][0];
    assert a.crew.status == CrewStatus.IDLE and a.crew.location_id == "CSC-North" and a.crew.task_fault_id == "";
    assert a.crew.name == "Crew A";
    assert "no power" in [root -->[?:ParseCache]][0].entries;
    assert len(_nodes()) == len(ids);
}
