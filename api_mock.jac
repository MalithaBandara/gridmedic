"""Mock API data in the final shapes (WP-B0). Deleted when WP-B4 lands real bodies.

Positions follow CLAUDE.md §6.1. States show a storm in progress: F1-B faulted
(SW1 locked out), T6/T8 suspected, F4 already corrected by a crew report.
"""

import from gm_types {
    Hazard,
    Lang,
    FaultKind,
    FaultStatus,
    CrewStatus,
    Complaint,
    Fault,
    Crew,
    CrewTask,
    SwitchStep,
    Action,
    CustomerStatus,
    Event,
    GridNodeView,
    GridEdgeView,
    GridView,
    Counters,
    Ack,
    ActionResult,
    label_fault,
    label_crew,
    label_complaint
}

glob MOCK_CLOCK: float = 9.5;

def _tx(id: str, x: int, y: int, homes: int, parent: str, powered: bool, status: str) -> GridNodeView {
    return GridNodeView(
        id=id, kind="transformer", x=x, y=y, label=id, homes=homes, parent_id=parent,
        energised=powered, has_power=powered, status=status
    );
}

def _homes(tx_id: str, tx_x: int, tx_y: int, powered: bool, reported_every: int) -> list[GridNodeView] {
    out: list[GridNodeView] = [];
    dy: int = -30 if tx_y < 300 else 30;
    for i in range(6) {
        hx: int = tx_x - 15 + (i % 3) * 15;
        hy: int = tx_y + dy + (i // 3) * 12 * (1 if dy > 0 else -1);
        out.append(
            GridNodeView(
                id=f"H-{tx_id}-{i + 1:03d}", kind="home", x=hx, y=hy, parent_id=tx_id,
                energised=powered, has_power=powered,
                reported=(reported_every > 0 and i % reported_every == 0)
            )
        );
    }
    return out;
}

def mock_grid -> GridView {
    nodes: list[GridNodeView] = [
        GridNodeView(id="SS1", kind="substation", x=200, y=300, label="Moratuwa Grid Substation"),
        GridNodeView(id="F1-A", kind="section", x=350, y=150, label="F1-A"),
        GridNodeView(id="SW1", kind="switch", x=450, y=150, label="SW1 (recloser)", closed=False, status="faulted"),
        GridNodeView(id="F1-B", kind="section", x=550, y=150, label="F1-B", energised=False, has_power=False, status="faulted"),
        GridNodeView(id="SW2", kind="switch", x=650, y=150, label="SW2", energised=False),
        GridNodeView(id="F1-C", kind="section", x=750, y=150, label="F1-C", energised=False, has_power=False),
        GridNodeView(id="F2-A", kind="section", x=350, y=450, label="F2-A"),
        GridNodeView(id="SW3", kind="switch", x=500, y=450, label="SW3"),
        GridNodeView(id="F2-B", kind="section", x=650, y=450, label="F2-B"),
        GridNodeView(id="TS1", kind="switch", x=800, y=300, label="TS1 (tie)", closed=False, tie=True),
        _tx("T1", 320, 90, 60, "F1-A", True, "normal"),
        _tx("T2", 380, 90, 45, "F1-A", True, "normal"),
        _tx("T3", 520, 90, 80, "F1-B", False, "faulted"),
        _tx("T4", 580, 90, 55, "F1-B", False, "faulted"),
        _tx("T5", 750, 90, 70, "F1-C", False, "faulted"),
        _tx("T6", 320, 520, 50, "F2-A", False, "suspected"),
        _tx("T7", 380, 520, 65, "F2-A", True, "normal"),
        _tx("T8", 620, 520, 40, "F2-B", False, "suspected"),
        _tx("T9", 680, 520, 75, "F2-B", True, "suspected"),
        _tx("T10", 740, 520, 60, "F2-B", True, "normal"),
        GridNodeView(id="CSC-North", kind="depot", x=80, y=150, label="CSC-North"),
        GridNodeView(id="CSC-South", kind="depot", x=80, y=450, label="CSC-South"),
        GridNodeView(id="POLE-23", kind="landmark", x=560, y=150, label="Pole 23", parent_id="F1-B", status="faulted"),
        GridNodeView(id="CREW-A", kind="crew", x=470, y=150, label="Crew A", status="normal"),
        GridNodeView(id="CREW-B", kind="crew", x=80, y=150, label="Crew B", status="normal"),
        GridNodeView(id="CREW-C", kind="crew", x=500, y=480, label="Crew C", status="normal")
    ];
    nodes.extend(_homes("T1", 320, 90, True, 0));
    nodes.extend(_homes("T3", 520, 90, False, 2));
    nodes.extend(_homes("T4", 580, 90, False, 3));
    nodes.extend(_homes("T5", 750, 90, False, 2));
    nodes.extend(_homes("T6", 320, 520, False, 2));
    nodes.extend(_homes("T7", 380, 520, True, 0));
    nodes.extend(_homes("T8", 620, 520, False, 2));
    nodes.extend(_homes("T9", 680, 520, True, 5));

    pairs: list[tuple[str, str]] = [
        ("SS1", "F1-A"), ("F1-A", "SW1"), ("SW1", "F1-B"), ("F1-B", "SW2"), ("SW2", "F1-C"),
        ("F1-A", "T1"), ("F1-A", "T2"), ("F1-B", "T3"), ("F1-B", "T4"), ("F1-C", "T5"),
        ("SS1", "F2-A"), ("F2-A", "SW3"), ("SW3", "F2-B"),
        ("F2-A", "T6"), ("F2-A", "T7"), ("F2-B", "T8"), ("F2-B", "T9"), ("F2-B", "T10")
    ];
    edges: list[GridEdgeView] = [GridEdgeView(from_id=a, to_id=b, kind="feeds") for (a, b) in pairs];
    edges.append(GridEdgeView(from_id="F1-C", to_id="TS1", kind="tie", closed=False));
    edges.append(GridEdgeView(from_id="F2-B", to_id="TS1", kind="tie", closed=False));
    for n in nodes {
        if n.kind == "home" {
            edges.append(GridEdgeView(from_id=n.parent_id, to_id=n.id, kind="feeds"));
        }
    }
    return GridView(
        nodes=nodes, edges=edges, clock_min=MOCK_CLOCK, running=True, speed=5,
        counters=Counters(complaints=184, faults=4, homes_off=310, homes_restored=0)
    );
}

def mock_faults -> list[Fault] {
    faults: list[Fault] = [
        Fault(
            id="FLT-001", kind=FaultKind.LINE_DOWN, device_id="F1-B", homes_affected=205,
            critical_loads=["HOSPITAL"], hazard=Hazard.WIRE_DOWN, priority=1723, confidence=0.9,
            status=FaultStatus.CREW_ASSIGNED, crew_id="CREW-A", eta_min=3, first_report_min=0.5,
            evidence=["62 of 205 homes downstream of F1-B reported", "3 hazard reports mention pole 23", "T3, T4 and T5 all report"],
            complaint_ids=["C0001", "C0004", "C0007"],
            explanation="Many homes under T3, T4 and T5 lost power together, which points to the line section F1-B rather than single transformers. Wire-down reports at Pole 23 and the hospital on T3 put it first."
        ),
        Fault(
            id="FLT-003", kind=FaultKind.TX_FUSE, device_id="T6", homes_affected=50,
            critical_loads=["WATER_PUMP"], priority=567, confidence=0.75,
            status=FaultStatus.SUSPECTED, first_report_min=1.5,
            evidence=["21 of 50 homes on T6 reported", "No reports elsewhere on F2-A except T7 (3)"],
            complaint_ids=["C0010", "C0012"]
        ),
        Fault(
            id="FLT-002", kind=FaultKind.TX_FUSE, device_id="T8", homes_affected=40,
            priority=56, confidence=0.75, status=FaultStatus.CREW_ASSIGNED, crew_id="CREW-B", eta_min=14,
            first_report_min=2.0,
            evidence=["17 of 40 homes on T8 reported"],
            complaint_ids=["C0020"]
        ),
        Fault(
            id="FLT-004", kind=FaultKind.SERVICE_WIRE, device_id="T9", street="Lake Road", homes_affected=15,
            priority=31, confidence=0.9, status=FaultStatus.CONFIRMED, crew_id="CREW-C",
            first_report_min=3.0, updated_by_crew=True,
            change_note="TX_FUSE@T9 (conf 0.4) -> SERVICE_WIRE@Lake Road (conf 0.9) - crew report",
            evidence=["7 of 75 homes on T9 reported, 6 of them on Lake Road", "Crew C: T9 fuses OK, service line down on Lake Road"],
            complaint_ids=["C0030"]
        )
    ];
    return [label_fault(f) for f in faults];
}

def mock_crews -> list[Crew] {
    crews: list[Crew] = [
        Crew(id="CREW-A", name="Crew A", depot_id="CSC-North", location_id="F1-B", status=CrewStatus.TRAVELLING, task_fault_id="FLT-001", eta_min=3, x=470, y=150),
        Crew(id="CREW-B", name="Crew B", depot_id="CSC-North", location_id="CSC-North", status=CrewStatus.TRAVELLING, task_fault_id="FLT-002", eta_min=14, x=80, y=150),
        Crew(id="CREW-C", name="Crew C", depot_id="CSC-South", location_id="T9", status=CrewStatus.ON_SITE, task_fault_id="FLT-004", x=680, y=520)
    ];
    return [label_crew(c) for c in crews];
}

def mock_tasks -> list[CrewTask] {
    return [
        CrewTask(crew_id="CREW-A", fault_id="FLT-001", eta_min=3, status_label="Travelling"),
        CrewTask(crew_id="CREW-B", fault_id="FLT-002", eta_min=14, status_label="Travelling"),
        CrewTask(crew_id="CREW-C", fault_id="FLT-004", eta_min=0, status_label="On site")
    ];
}

def mock_complaints(since_min: float) -> list[Complaint] {
    items: list[Complaint] = [
        Complaint(id="C0001", text="BD 4512300017", time_min=0.5, consumer_no="4512300017", home_id="H-T3-017"),
        Complaint(id="C0002", text="Wire fallen on the road near pole 23, sparks!", time_min=0.8, consumer_no="4512400003", hazard=Hazard.WIRE_DOWN, landmark="pole 23", home_id="H-T4-003"),
        Complaint(id="C0003", text="කණුව ළඟ වයරයක් බිම වැටිලා තියෙනවා", time_min=1.1, consumer_no="4512300042", lang=Lang.SI, hazard=Hazard.WIRE_DOWN, home_id="H-T3-042"),
        Complaint(id="C0004", text="Water pump area has no electricity", time_min=1.6, consumer_no="4512600008", home_id="H-T6-008"),
        Complaint(id="C0005", text="BD 4512300017", time_min=4.0, consumer_no="4512300017", home_id="H-T3-017", is_duplicate=True),
        Complaint(id="C0006", text="රෑ 7 ඉඳන් කරන්ට් නැහැ", time_min=6.2, consumer_no="4512800011", lang=Lang.SI, home_id="H-T8-011"),
        Complaint(id="C0007", text="No power since 7pm", time_min=8.9, consumer_no="4512900004", home_id="H-T9-004")
    ];
    return [label_complaint(c) for c in items if c.time_min >= since_min];
}

def mock_events(since_min: float) -> list[Event] {
    items: list[Event] = [
        Event(time_min=0.5, kind="complaint", text="C0001 from 4512300017 (T3)"),
        Event(time_min=2.0, kind="fault_new", text="FLT-001 LINE_DOWN at F1-B suspected: 3 transformers reporting", fault_id="FLT-001"),
        Event(time_min=2.5, kind="dispatch", text="Crew A -> FLT-001 (F1-B), ETA 8 min", fault_id="FLT-001"),
        Event(time_min=4.0, kind="duplicate", text="C0005 duplicate of C0001 (same consumer within 10 min)"),
        Event(time_min=8.0, kind="mind_change", text="FLT-004: TX_FUSE@T9 (conf 0.4) -> SERVICE_WIRE@Lake Road (conf 0.9) - crew report", fault_id="FLT-004")
    ];
    return [e for e in items if e.time_min >= since_min];
}

def mock_actions -> list[Action] {
    return [
        Action(
            id="ACT-1", kind="tie_restore", steps=[SwitchStep(switch_id="TS1", action="close")],
            homes_restored=70, safe=False, reason="Step 1 energises work zone F1-B where Crew A is working"
        ),
        Action(
            id="ACT-2", kind="tie_restore",
            steps=[SwitchStep(switch_id="SW2", action="open"), SwitchStep(switch_id="TS1", action="close")],
            homes_restored=70, safe=True, reason="F2 load 290 + 70 = 360 <= 700; no work zone energised"
        )
    ];
}

def mock_status(consumer_no: str) -> CustomerStatus {
    if consumer_no.startswith("45123") or consumer_no.startswith("45124") {
        return CustomerStatus(
            consumer_no=consumer_no, has_power=False, fault_id="FLT-001", eta_min=35,
            status_text="Fault found - Crew A assigned - ETA 35 min"
        );
    }
    return CustomerStatus(consumer_no=consumer_no, has_power=True, status_text="Power is on in your area");
}

def mock_ack(message: str) -> Ack {
    return Ack(ok=True, message=message, clock_min=MOCK_CLOCK);
}

def mock_crew_report(crew_id: str) -> Fault {
    for f in mock_faults() {
        if f.crew_id == crew_id {
            return f;
        }
    }
    return mock_faults()[3];
}

def mock_apply(action_id: str) -> ActionResult {
    for a in mock_actions() {
        if a.id == action_id {
            if not a.safe {
                return ActionResult(ok=False, message=a.reason, action=a);
            }
            a.applied = True;
            return ActionResult(
                ok=True, message=f"Applied {a.id}: {a.homes_restored} homes restored", action=a,
                counters=Counters(complaints=184, faults=4, homes_off=240, homes_restored=70)
            );
        }
    }
    return ActionResult(ok=False, message=f"No action {action_id}");
}

def mock_submit(text: str, consumer_no: str) -> Complaint {
    return label_complaint(
        Complaint(id="C9999", text=text, time_min=MOCK_CLOCK, consumer_no=consumer_no)
    );
}
