"""GridMedic shared types: the contract between parser, localiser, API and UI.

Owned by Person B. Do not change field names or order without B's OK.
Named gm_types (not types) because Python's stdlib `types` module shadows it.

Enums reach the browser as numbers, so every obj the UI shows also carries
`*_label` strings. Fill them with the `label_*` helpers before returning.
"""

enum Hazard { NONE, WIRE_DOWN, SPARKS, FIRE, TRANSFORMER_NOISE }

sem Hazard.NONE = "No danger mentioned: only a loss of power, low voltage or a question.";
sem Hazard.WIRE_DOWN = "A power line or wire has fallen, is hanging low, or is on the road/ground.";
sem Hazard.SPARKS = "Sparks, arcing, flashes or a burning smell from lines or transformers.";
sem Hazard.FIRE = "Flames or a fire at a pole, line, transformer or meter.";
sem Hazard.TRANSFORMER_NOISE = "A bang, explosion sound, buzzing or humming from a transformer.";

enum FaultKind { LINE_DOWN, TX_FUSE, SERVICE_WIRE, BREAKER_TRIP, UNKNOWN }

sem FaultKind.LINE_DOWN = "A medium-voltage line section is broken or down; everything downstream is off.";
sem FaultKind.TX_FUSE = "A distribution transformer's fuse has blown; only that transformer's homes are off.";
sem FaultKind.SERVICE_WIRE = "A low-voltage street or service wire is down; only homes on that street are off.";
sem FaultKind.BREAKER_TRIP = "A breaker or recloser tripped with no damage found; it can be reset.";
sem FaultKind.UNKNOWN = "The cause is not known yet.";

enum FaultStatus { SUSPECTED, CONFIRMED, CREW_ASSIGNED, REPAIRING, RESTORED, CLOSED }

sem FaultStatus.SUSPECTED = "Inferred from complaints only; no crew has seen it yet.";
sem FaultStatus.CONFIRMED = "A crew on site has confirmed the fault.";
sem FaultStatus.CREW_ASSIGNED = "A crew is on the way.";
sem FaultStatus.REPAIRING = "A crew is repairing it now.";
sem FaultStatus.RESTORED = "Power is back for the affected homes.";
sem FaultStatus.CLOSED = "The fault is finished and needs no more work.";

enum CrewStatus { IDLE, TRAVELLING, ON_SITE, DONE }

enum Lang { EN, SI, MIXED }

sem Lang.EN = "English.";
sem Lang.SI = "Sinhala (Sinhala script or Sinhala written in Latin letters).";
sem Lang.MIXED = "A mix of Sinhala and English in one message.";

obj Complaint {
    has id: str,
        text: str,
        time_min: float,
        consumer_no: str = "",
        lang: Lang = Lang.EN,
        hazard: Hazard = Hazard.NONE,
        landmark: str = "",
        home_id: str = "",
        is_duplicate: bool = False,
        hazard_label: str = "";
}

obj Fault {
    has id: str,
        kind: FaultKind,
        device_id: str,
        homes_affected: int,
        street: str = "",
        critical_loads: list[str] = [],
        hazard: Hazard = Hazard.NONE,
        priority: int = 0,
        confidence: float = 0.5,
        status: FaultStatus = FaultStatus.SUSPECTED,
        evidence: list[str] = [],
        complaint_ids: list[str] = [],
        first_report_min: float = 0.0,
        crew_id: str = "",
        eta_min: int = 0,
        updated_by_crew: bool = False,
        change_note: str = "",
        explanation: str = "",
        kind_label: str = "",
        hazard_label: str = "",
        status_label: str = "";
}

# parse_crew_report's local CrewFinding is copied into this (CLAUDE.md §8.6).
obj FaultUpdate {
    has fault_id: str,
        device_ok: bool,
        new_kind: FaultKind,
        new_device_id: str = "",
        street: str = "",
        restored: bool = False,
        repair_eta_min: int = 0,
        note: str = "";
}

obj Crew {
    has id: str,
        depot_id: str,
        location_id: str,
        status: CrewStatus,
        name: str = "",
        task_fault_id: str = "",
        eta_min: int = 0,
        x: int = 0,
        y: int = 0,
        status_label: str = "";
}

obj CrewTask {
    has crew_id: str,
        fault_id: str,
        eta_min: int,
        status_label: str = "";
}

# action: "open" | "close"
obj SwitchStep {
    has switch_id: str,
        action: str;
}

obj Action {
    has id: str,
        kind: str,
        steps: list[SwitchStep],
        homes_restored: int,
        safe: bool,
        reason: str,
        applied: bool = False;
}

obj CustomerStatus {
    has consumer_no: str,
        has_power: bool,
        status_text: str,
        fault_id: str = "",
        eta_min: int = 0;
}

# One parsed free-text complaint, as stored in ParseCache (keyed by raw text).
obj ParsedText {
    has index: int,
        lang: Lang,
        hazard: Hazard,
        landmark: str;
}

# kind: one of the event kinds in PLAN.md §2.1
obj Event {
    has time_min: float,
        kind: str,
        text: str,
        fault_id: str = "";
}

# kind: substation | section | switch | transformer | home | depot | landmark | crew
# status: normal | suspected | faulted | restored
obj GridNodeView {
    has id: str,
        kind: str,
        x: int,
        y: int,
        label: str = "",
        energised: bool = True,
        has_power: bool = True,
        reported: bool = False,
        closed: bool = True,
        status: str = "normal",
        homes: int = 0,
        parent_id: str = "",
        work_zone: bool = False,
        tie: bool = False,
        powered_by: str = "",       # microgrid id supplying this transformer
        battery_min: int = 0,       # microgrid views only
        battery_max: int = 0,
        supplying: bool = False,
        islanded: bool = False,
        isolated: bool = False;
}

# kind: feeds | tie
obj GridEdgeView {
    has from_id: str,
        to_id: str,
        kind: str,
        closed: bool = True;
}

obj Counters {
    has complaints: int = 0,
        faults: int = 0,
        homes_off: int = 0,
        homes_restored: int = 0;
}

obj GridView {
    has nodes: list[GridNodeView],
        edges: list[GridEdgeView],
        clock_min: float,
        counters: Counters,
        running: bool = False,
        speed: int = 1;
}

# Generic reply for start_storm, tick and reset.
obj Ack {
    has ok: bool,
        message: str = "",
        clock_min: float = 0.0;
}

obj ActionResult {
    has ok: bool,
        message: str,
        action: Action | None = None,
        counters: Counters | None = None;
}

def hazard_label(h: Hazard) -> str;
def kind_label(k: FaultKind) -> str;
def status_label(s: FaultStatus) -> str;
def crew_status_label(s: CrewStatus) -> str;
def label_fault(f: Fault) -> Fault;
def label_crew(c: Crew) -> Crew;
def label_complaint(c: Complaint) -> Complaint;
