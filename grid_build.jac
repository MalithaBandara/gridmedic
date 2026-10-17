"""Demo grid builder (WP-A1): the fictional grid from CLAUDE.md §6.1 under root.

1 substation fed by transmission line TL1, 2 feeders, 5 sections, 3 switches + tie TS1, 10 transformers,
600 homes, 5 priority facilities, Pole 23, 2 microgrids (MG-HOSP on T3, MG-RES
on T5), 2 depots and 3 crews.

build_grid() is idempotent: if SS1 exists it returns it. reset_grid() puts the
grid back to its normal state before a storm and keeps ParseCache.
Facilities are tags in Transformer.critical plus Landmark nodes; they are not
homes, so the 600-home totals and the 700-home feeder capacity are unchanged.
"""

import from gm_types { Crew, CrewStatus }
import from grid {
    GridNode,
    Feeds,
    Located,
    Substation,
    TransmissionLine,
    Section,
    Switch,
    Transformer,
    Home,
    Depot,
    Landmark,
    Microgrid,
    CrewNode,
    FaultNode,
    SimState,
    ParseCache,
    EventLog,
    ComplaintLog,
    ActionStore,
    children
}

glob FEEDER_CAPACITY: int = 700;

# id, name, kV, x, y: the line from the national grid into SS1
glob TRANSMISSION: tuple[str, str, int, int, int] = ("TL1", "132 kV line from the national grid", 132, 110, 300);

# id, feeder, x, y
glob SECTIONS: list[tuple[str, str, int, int]] = [
    ("F1-A", "F1", 350, 150),
    ("F1-B", "F1", 550, 150),
    ("F1-C", "F1", 750, 150),
    ("F2-A", "F2", 350, 450),
    ("F2-B", "F2", 650, 450)
];

# id, kind, x, y, upstream section, downstream section
glob SWITCHES: list[tuple[str, str, int, int, str, str]] = [
    ("SW1", "recloser", 450, 150, "F1-A", "F1-B"),
    ("SW2", "switch", 650, 150, "F1-B", "F1-C"),
    ("SW3", "switch", 500, 450, "F2-A", "F2-B")
];

# n (Tn), section, x, y, critical tags, streets (name, homes) in numbering order
glob TRANSFORMERS: list[tuple[int, str, int, int, list[str], list[tuple[str, int]]]] = [
    (1, "F1-A", 320, 90, ["SCHOOL"], [("Railway Avenue", 30), ("Galle Road", 30)]),
    (2, "F1-A", 380, 90, [], [("Church Road", 25), ("Market Street", 20)]),
    (3, "F1-B", 520, 90, ["HOSPITAL"], [("Hospital Road", 45), ("Pansala Road", 35)]),
    (4, "F1-B", 580, 90, [], [("Old Mill Road", 30), ("Canal Road", 25)]),
    (5, "F1-C", 750, 90, ["SCHOOL"], [("School Lane", 40), ("Bridge Road", 30)]),
    (6, "F2-A", 320, 520, ["WATER_PUMP"], [("Reservoir Road", 25), ("Pump House Road", 25)]),
    (7, "F2-A", 380, 520, [], [("Beach Road", 35), ("Fisheries Road", 30)]),
    (8, "F2-B", 620, 520, [], [("Park Road", 20), ("Kanatta Road", 20)]),
    (9, "F2-B", 680, 520, [], [("Lake Road", 15), ("Temple Road", 30), ("Station Road", 30)]),
    (10, "F2-B", 740, 520, ["POLICE"], [("Ward Place", 30), ("Factory Road", 30)])
];

# id, name, section, x, y. The parser matches a landmark by its full name.
glob LANDMARKS: list[tuple[str, str, str, int, int]] = [
    ("POLE-23", "Pole 23", "F1-B", 560, 150),
    ("LM-HOSPITAL", "Lakeview General Hospital", "F1-B", 500, 60),
    ("LM-PUMP", "Reservoir Road Pumping Station", "F2-A", 300, 550),
    ("LM-POLICE", "Ward Place Police Station", "F2-B", 760, 550),
    ("LM-SCHOOL-BRIDGE", "Bridge Road Maha Vidyalaya", "F1-C", 770, 60),
    ("LM-SCHOOL-RAILWAY", "Railway Avenue Primary School", "F1-A", 300, 60)
];

# id, name, transformer served, kind, x, y, capacity (homes), critical_only,
# landmark powered, battery minutes. The hospital set carries only the hospital
# (critical_only); the residential set carries all of its transformer's homes.
glob MICROGRIDS: list[tuple[str, str, str, str, int, int, int, bool, str, int]] = [
    ("MG-HOSP", "Lakeview Hospital backup", "T3", "DIESEL_BATTERY", 455, 100, 20, True, "LM-HOSPITAL", 240),
    ("MG-RES", "Bridge Road solar + battery", "T5", "SOLAR_BATTERY", 815, 100, 80, False, "", 120)
];

# id, name, x, y
glob DEPOTS: list[tuple[str, str, int, int]] = [
    ("CSC-North", "CSC-North", 80, 150),
    ("CSC-South", "CSC-South", 80, 450)
];

# id, display name, depot
glob CREWS: list[tuple[str, str, str]] = [
    ("CREW-A", "Crew A", "CSC-North"),
    ("CREW-B", "Crew B", "CSC-North"),
    ("CREW-C", "Crew C", "CSC-South")
];

# Home dots: rows of 10, 6 px apart; F1 homes above their transformer, F2 below.
glob HOME_COLS: int = 10;
glob HOME_STEP: int = 6;
glob HOME_GAP: int = 12;

"""Consumer number for transformer Tn, home i (from 1): T3 home 17 is 4512300017."""
def consumer_no(n: int, i: int) -> str {
    return "451" + str(20 + n) + f"{i:05d}";
}

"""Home id for transformer Tn, home i: H-T3-017."""
def home_id(n: int, i: int) -> str {
    return f"H-T{n}-{i:03d}";
}

"""Build the demo grid under root, or return SS1 if it is already there."""
def build_grid -> Substation {
    existing = [s for s in [root -->[?:Substation]] if children(s)];
    if existing {
        _add_microgrids(existing[0]);    # graphs persisted before microgrids existed
        _add_transmission(existing[0]);
        _ensure_state();
        return existing[0];
    }
    for orphan in [root -->[?:Substation]] {
        del orphan;
    }
    ss = Substation(id="SS1", name="Moratuwa Grid Substation", x=200, y=300);
    root ++> ss;

    secs: dict[str, Section] = {};
    for (sid, feeder, x, y) in SECTIONS {
        secs[sid] = Section(id=sid, feeder=feeder, x=x, y=y);
    }
    ss +>:Feeds(capacity=FEEDER_CAPACITY):+> secs["F1-A"];
    ss +>:Feeds(capacity=FEEDER_CAPACITY):+> secs["F2-A"];
    for (wid, kind, x, y, up, down) in SWITCHES {
        sw = Switch(id=wid, kind=kind, x=x, y=y);
        secs[up] +>:Feeds:+> sw;
        sw +>:Feeds:+> secs[down];
    }
    # The tie is fed from both ends; normally open.
    ts1 = Switch(id="TS1", kind="tie", x=800, y=300, closed=False, normally_open=True);
    secs["F1-C"] +>:Feeds:+> ts1;
    secs["F2-B"] +>:Feeds:+> ts1;

    for (n, sid, x, y, critical, streets) in TRANSFORMERS {
        _transformer(secs[sid], n, x, y, critical, streets);
    }
    _add_microgrids(ss);
    _add_transmission(ss);
    for (lid, name, sid, x, y) in LANDMARKS {
        lm = Landmark(id=lid, name=name, section_id=sid, x=x, y=y);
        lm +>:Located:+> secs[sid];
    }

    depots: dict[str, Depot] = {};
    for (did, name, x, y) in DEPOTS {
        d = Depot(id=did, name=name, x=x, y=y);
        root ++> d;
        depots[did] = d;
    }
    for (cid, name, did) in CREWS {
        cn = CrewNode(crew=_idle_crew(cid, name, depots[did]));
        root ++> cn;
        cn +>:Located:+> depots[did];
    }

    _ensure_state();
    return ss;
}

"""Put the grid back to normal: switches normal, everything healthy and
energised, tallies and faults cleared, crews idle at their depots. Keeps ParseCache."""
def reset_grid {
    ss = build_grid();
    for n in grid_nodes(ss) {
        n.energised = True;
        if isinstance(n, Section) {
            n.work_zone = False;
            n.reports = 0;
            n.line_ok = True;
        } elif isinstance(n, Switch) {
            n.closed = not n.normally_open;
            n.locked_out = False;
        } elif isinstance(n, Transformer) {
            n.reports = 0;
            n.fuse_ok = True;
            ok: dict[str, bool] = {};
            for street in n.service_ok.keys() {
                ok[street] = True;
            }
            n.service_ok = ok;
        } elif isinstance(n, Home) {
            n.has_power = True;
            n.reported = False;
        } elif isinstance(n, Microgrid) {
            n.battery_min = n.battery_max;
            n.isolated = False;
            n.islanded = False;
            n.supplying = False;
        }
    }

    for tl in [root -->[?:TransmissionLine]] {
        tl.line_ok = True;
        tl.energised = True;
    }
    for fn in [root -->[?:FaultNode]] {
        del fn;
    }
    depots: dict[str, Depot] = {};
    for d in [root -->[?:Depot]] {
        depots[d.id] = d;
    }
    names: dict[str, str] = {};
    for (cid, name, _did) in CREWS {
        names[cid] = name;
    }
    for cn in [root -->[?:CrewNode]] {
        home_depot = depots.get(cn.crew.depot_id);
        if home_depot {
            # Replace the obj, so the change persists on the node.
            cn.crew = _idle_crew(cn.crew.id, names.get(cn.crew.id, cn.crew.name), home_depot);
        }
    }

    for el in [root -->[?:EventLog]] {
        el.events = [];
    }
    for cl in [root -->[?:ComplaintLog]] {
        cl.items = [];
    }
    for st in [root -->[?:ActionStore]] {
        st.actions = [];
    }
    for sim in [root -->[?:SimState]] {
        sim.clock_min = 0.0;
        sim.running = False;
        sim.speed = 1;
        sim.next_complaint_idx = 0;
        sim.next_fault_no = 1;
        sim.next_complaint_no = 1;
    }
}

"""Every grid node reachable from SS1 over Feeds, each once (TS1 has two parents)."""
def grid_nodes(ss: Substation) -> list[GridNode] {
    seen: set[str] = set();
    out: list[GridNode] = [];
    queue: list[GridNode] = [ss];
    while queue {
        n = queue.pop(0);
        if n.id in seen {
            continue;
        }
        seen.add(n.id);
        out.append(n);
        queue.extend(children(n));
    }
    return out;
}

def _transformer(sec: Section, n: int, x: int, y: int, critical: list[str], streets: list[tuple[str, int]]) {
    total = sum([count for (_street, count) in streets]);
    service: dict[str, bool] = {};
    for (street, _count) in streets {
        service[street] = True;
    }
    tid = f"T{n}";
    t = Transformer(
        id=tid,
        x=x,
        y=y,
        homes=total,
        feeder=sec.feeder,
        critical=list(critical),
        service_ok=service
    );
    sec +>:Feeds:+> t;

    above = sec.feeder == "F1";
    i = 1;
    for (street, count) in streets {
        for _k in range(count) {
            col = (i - 1) % HOME_COLS;
            row = (i - 1) // HOME_COLS;
            hx = x - (HOME_COLS - 1) * HOME_STEP // 2 + col * HOME_STEP;
            hy = y - HOME_GAP - row * HOME_STEP if above else y + HOME_GAP + row * HOME_STEP;
            t +>:Feeds:+> Home(
                id=home_id(n, i),
                x=hx,
                y=hy,
                consumer_no=consumer_no(n, i),
                street=street,
                transformer_id=tid
            );
            i += 1;
        }
    }
}

"""TL1 under root, feeding SS1, unless it is already there."""
def _add_transmission(ss: Substation) {
    tls = [root -->[?:TransmissionLine]];
    if tls {
        tl = tls[0];
        has_edge = any([x.id == ss.id for x in [tl -->] if isinstance(x, Substation)]);
        if not has_edge {
            tl +>:Feeds(capacity=2 * FEEDER_CAPACITY):+> ss;
        }
        return;
    }
    (tid, name, kv, x, y) = TRANSMISSION;
    tl = TransmissionLine(id=tid, name=name, kv=kv, x=x, y=y);
    root ++> tl;
    tl +>:Feeds(capacity=2 * FEEDER_CAPACITY):+> ss;
}

"""Hang each microgrid off the transformer it serves, unless it is already there."""
def _add_microgrids(ss: Substation) {
    nodes = grid_nodes(ss);
    have: set[str] = set([n.id for n in nodes if isinstance(n, Microgrid)]);
    for (mid, name, tid, kind, x, y, cap, crit, lmid, mins) in MICROGRIDS {
        if mid in have {
            continue;
        }
        for t in [n for n in nodes if isinstance(n, Transformer) and n.id == tid] {
            t +>:Located:+> Microgrid(
                id=mid, name=name, kind=kind, x=x, y=y, capacity_homes=cap,
                critical_only=crit, landmark_id=lmid, battery_max=mins, battery_min=mins
            );
        }
    }
}

def _idle_crew(cid: str, name: str, depot: Depot) -> Crew {
    return Crew(
        id=cid,
        depot_id=depot.id,
        location_id=depot.id,
        status=CrewStatus.IDLE,
        name=name,
        x=depot.x,
        y=depot.y
    );
}

"""One of each operational node under root, created only if missing."""
def _ensure_state {
    if not [root -->[?:SimState]] {
        root ++> SimState();
    }
    if not [root -->[?:ParseCache]] {
        root ++> ParseCache();
    }
    if not [root -->[?:EventLog]] {
        root ++> EventLog();
    }
    if not [root -->[?:ComplaintLog]] {
        root ++> ComplaintLog();
    }
    if not [root -->[?:ActionStore]] {
        root ++> ActionStore();
    }
}
