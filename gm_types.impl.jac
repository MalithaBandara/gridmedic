"""Display labels for enums, so the UI never has to decode enum numbers."""

impl hazard_label(h: Hazard) -> str {
    match h {
        case Hazard.WIRE_DOWN:
            return "Wire down";
        case Hazard.SPARKS:
            return "Sparks";
        case Hazard.FIRE:
            return "Fire";
        case Hazard.TRANSFORMER_NOISE:
            return "Transformer noise";
        case _:
            return "";
    }
}

impl kind_label(k: FaultKind) -> str {
    match k {
        case FaultKind.LINE_DOWN:
            return "Line down";
        case FaultKind.TX_FUSE:
            return "Transformer fuse";
        case FaultKind.SERVICE_WIRE:
            return "Service wire";
        case FaultKind.BREAKER_TRIP:
            return "Breaker trip";
        case FaultKind.TRANSMISSION:
            return "Transmission line";
        case _:
            return "Unknown";
    }
}

impl status_label(s: FaultStatus) -> str {
    match s {
        case FaultStatus.SUSPECTED:
            return "Suspected";
        case FaultStatus.CONFIRMED:
            return "Confirmed";
        case FaultStatus.CREW_ASSIGNED:
            return "Crew assigned";
        case FaultStatus.REPAIRING:
            return "Repairing";
        case FaultStatus.RESTORED:
            return "Restored";
        case _:
            return "Closed";
    }
}

impl crew_status_label(s: CrewStatus) -> str {
    match s {
        case CrewStatus.IDLE:
            return "Idle";
        case CrewStatus.TRAVELLING:
            return "Travelling";
        case CrewStatus.ON_SITE:
            return "On site";
        case _:
            return "Done";
    }
}

impl label_fault(f: Fault) -> Fault {
    f.kind_label = kind_label(f.kind);
    f.hazard_label = hazard_label(f.hazard);
    f.status_label = status_label(f.status);
    return f;
}

impl label_crew(c: Crew) -> Crew {
    c.status_label = crew_status_label(c.status);
    return c;
}

impl label_complaint(c: Complaint) -> Complaint {
    c.hazard_label = hazard_label(c.hazard);
    return c;
}
