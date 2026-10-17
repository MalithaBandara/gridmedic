"""PLACEHOLDER demo grid and storm, so the app runs end to end today.

Person A's grid_build.jac (WP-A1) and grid_storm.jac (WP-A2) replace this
file: when they land, change the two `import from scenario_placeholder`
lines in sim.jac to `grid_build` / `grid_storm` and delete this file.
Same signatures as the real modules (see PLAN.md WP-A1 / WP-A2).

The storm here is a small, BD-SMS-heavy subset of CLAUDE.md §6.2-6.3:
F1 line down (T3, T4, T5), F2 T8 fuse, F3 T6 fuse, F4 Lake Road under T9,
3 false reports from T7, 5 duplicates, 2 landmark-only complaints.
"""

import from random { Random }
import from gm_types { Crew, CrewStatus, Complaint }
import from grid {
    GridNode,
    Feeds,
    Located,
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
    children
}

glob _TXS: list[tuple[str, str, int, int, int, list[str]]] = [
    ("T1", "F1-A", 320, 90, 60, []),
    ("T2", "F1-A", 380, 90, 45, []),
    ("T3", "F1-B", 520, 90, 80, ["HOSPITAL"]),
    ("T4", "F1-B", 580, 90, 55, []),
    ("T5", "F1-C", 750, 90, 70, []),
    ("T6", "F2-A", 320, 520, 50, ["WATER_PUMP"]),
    ("T7", "F2-A", 380, 520, 65, []),
    ("T8", "F2-B", 620, 520, 40, []),
    ("T9", "F2-B", 680, 520, 75, []),
    ("T10", "F2-B", 740, 520, 60, [])
];

def consumer_no(tx: str, i: int) -> str {
    return "451" + str(20 + int(tx[1:])) + f"{i:05d}";
}

def _street(tx: str, i: int) -> str {
    if tx == "T9" {
        return "Lake Road" if i <= 15 else ("Temple Road" if i <= 45 else "Station Road");
    }
    return f"{tx} Lane " + ("A" if i % 2 == 0 else "B");
}

def _all_nodes -> list[GridNode] {
    seen: set[str] = set();
    out: list[GridNode] = [];
    q: list[GridNode] = [s for s in [root -->[?:Substation]]];
    while q {
        n = q.pop(0);
        if n.id in seen {
            continue;
        }
        seen.add(n.id);
        out.append(n);
        q.extend(children(n));
    }
    return out;
}

def build_grid -> Substation {
    subs = [root -->[?:Substation]];
    if subs {
        return subs[0];
    }
    ss = Substation(id="SS1", name="Moratuwa Grid Substation", x=200, y=300);
    root ++> ss;
    nodes: dict[str, GridNode] = {"SS1": ss};
    for (sid, feeder, x, y) in [("F1-A", "F1", 350, 150), ("F1-B", "F1", 550, 150), ("F1-C", "F1", 750, 150), ("F2-A", "F2", 350, 450), ("F2-B", "F2", 650, 450)] {
        nodes[sid] = Section(id=sid, feeder=feeder, x=x, y=y);
    }
    nodes["SW1"] = Switch(id="SW1", kind="recloser", x=450, y=150);
    nodes["SW2"] = Switch(id="SW2", x=650, y=150);
    nodes["SW3"] = Switch(id="SW3", x=500, y=450);
    nodes["TS1"] = Switch(id="TS1", kind="tie", closed=False, normally_open=True, x=800, y=300);
    for (a, b, cap) in [("SS1", "F1-A", 700), ("F1-A", "SW1", 0), ("SW1", "F1-B", 0), ("F1-B", "SW2", 0), ("SW2", "F1-C", 0), ("SS1", "F2-A", 700), ("F2-A", "SW3", 0), ("SW3", "F2-B", 0), ("F1-C", "TS1", 0), ("F2-B", "TS1", 0)] {
        nodes[a] +>:Feeds(capacity=cap):+> nodes[b];
    }
    for (tid, sid, x, y, homes, crit) in _TXS {
        t = Transformer(id=tid, feeder=sid[:2], x=x, y=y, homes=homes, critical=crit);
        nodes[sid] +>:Feeds:+> t;
        streets: dict[str, bool] = {};
        above: bool = y < 300;
        for i in range(1, homes + 1) {
            st: str = _street(tid, i);
            streets[st] = True;
            col: int = (i - 1) % 10;
            row: int = (i - 1) // 10;
            hx: int = x - 18 + col * 4;
            hy: int = (y - 18 - row * 4) if above else (y + 18 + row * 4);
            t +>:Feeds:+> Home(id=f"H-{tid}-{i:03d}", consumer_no=consumer_no(tid, i), street=st, transformer_id=tid, x=hx, y=hy);
        }
        t.service_ok = streets;
    }
    depots: dict[str, Depot] = {};
    for (did, x, y) in [("CSC-North", 80, 150), ("CSC-South", 80, 450)] {
        d = Depot(id=did, name=did, x=x, y=y);
        root ++> d;
        depots[did] = d;
    }
    for (cid, dep) in [("CREW-A", "CSC-North"), ("CREW-B", "CSC-North"), ("CREW-C", "CSC-South")] {
        d = depots[dep];
        cn = CrewNode(crew=Crew(id=cid, name="Crew " + cid[-1], depot_id=dep, location_id=dep, status=CrewStatus.IDLE, x=d.x, y=d.y));
        root ++> cn;
        cn +>:Located:+> d;
    }
    lm = Landmark(id="POLE-23", name="Pole 23", section_id="F1-B", x=560, y=150);
    root ++> lm;
    lm +>:Located:+> nodes["F1-B"];
    if not [root -->[?:SimState]] {
        root ++> SimState();
    }
    if not [root -->[?:ParseCache]] {
        root ++> ParseCache();
    }
    return ss;
}

def reset_grid {
    for n in _all_nodes() {
        n.energised = True;
        if isinstance(n, Switch) {
            n.closed = not n.normally_open;
            n.locked_out = False;
        } elif isinstance(n, Section) {
            n.line_ok = True;
            n.reports = 0;
            n.work_zone = False;
        } elif isinstance(n, Transformer) {
            n.fuse_ok = True;
            n.reports = 0;
            ok: dict[str, bool] = {};
            for k in n.service_ok.keys() {
                ok[str(k)] = True;
            }
            n.service_ok = ok;
        } elif isinstance(n, Home) {
            n.has_power = True;
            n.reported = False;
        }
    }
    depots: dict[str, Depot] = {d.id: d for d in [root -->[?:Depot]]};
    for cn in [root -->[?:CrewNode]] {
        c = cn.crew;
        d = depots.get(c.depot_id);
        c.status = CrewStatus.IDLE;
        c.location_id = c.depot_id;
        c.task_fault_id = "";
        c.eta_min = 0;
        if d {
            c.x = d.x;
            c.y = d.y;
        }
        cn.crew = c;
    }
}

def apply_storm_truth(f5: bool = False) {
    for n in _all_nodes() {
        if isinstance(n, Section) and n.id == "F1-B" {
            n.line_ok = False;
        } elif isinstance(n, Switch) and n.id == "SW1" {
            n.closed = False;
            n.locked_out = True;
        } elif isinstance(n, Transformer) {
            if n.id in ["T8", "T6"] or (f5 and n.id == "T4") {
                n.fuse_ok = False;
            }
            if n.id == "T9" {
                cut: dict[str, bool] = dict(n.service_ok);
                cut["Lake Road"] = False;
                n.service_ok = cut;
            }
        }
    }
}

# Bursty: most reports in the first 8 minutes.
def _time(rng: Random, start: float) -> float {
    t: float = start + rng.expovariate(1.0 / 3.0);
    return float(f"{min(t, 19.9):.1f}");
}

def generate_complaints(seed: int = 17) -> list[Complaint] {
    rng = Random(seed);
    out: list[Complaint] = [];
    # (transformer, homes that can report, share reporting, first report min)
    groups: list[tuple[str, list[int], float, float]] = [
        ("T3", list(range(1, 81)), 0.4, 0.3),
        ("T4", list(range(1, 56)), 0.4, 0.4),
        ("T5", list(range(1, 71)), 0.35, 0.5),
        ("T8", list(range(1, 41)), 0.45, 1.0),
        ("T6", list(range(1, 51)), 0.4, 1.2),
        ("T9", list(range(1, 16)), 0.5, 2.0)
    ];
    for (tx, homes, share, start) in groups {
        picked: list[int] = rng.sample(homes, max(1, int(len(homes) * share)));
        for i in picked {
            cn: str = consumer_no(tx, i);
            out.append(Complaint(id="", text=f"BD {cn}", consumer_no=cn, time_min=_time(rng, start)));
        }
    }
    # 3 false reports from T7 (those homes still have power)
    for i in [5, 22, 41] {
        cn = consumer_no("T7", i);
        out.append(Complaint(id="", text=f"BD {cn}", consumer_no=cn, time_min=float(4 + i % 7)));
    }
    # 5 duplicates: the same consumer again within 10 minutes
    firsts: list[Complaint] = [c for c in out if c.consumer_no.startswith("45123")][:5];
    for c in firsts {
        out.append(Complaint(id="", text=c.text, consumer_no=c.consumer_no, time_min=float(f"{min(c.time_min + 4.0, 19.9):.1f}")));
    }
    # 2 landmark-only complaints (no consumer number)
    out.append(Complaint(id="", text="Wire fallen on the road near pole 23, sparks!", time_min=0.8));
    out.append(Complaint(id="", text="Wire down near Pole 23", time_min=2.6));
    out = sorted(out, key=lambda c: Complaint : c.time_min);
    for (k, c) in enumerate(out) {
        c.id = f"C{k + 1:04d}";
    }
    return out;
}

def f5_followup_complaints(start_min: float) -> list[Complaint] {
    out: list[Complaint] = [];
    for (k, i) in enumerate([3, 9, 14, 20, 27, 33, 41, 50]) {
        cn = consumer_no("T4", i);
        out.append(Complaint(id=f"C9{k + 1:03d}", text=f"BD {cn}", consumer_no=cn, time_min=start_min + k * 0.6));
    }
    return out;
}
