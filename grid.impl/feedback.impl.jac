"""CrewReport walker + FaultNode re-evaluation (WP-B5, CLAUDE.md §8.6)."""

# Walk from root to the one FaultNode the report is about.
impl CrewReport.find {
    for fn in [here -->[?:FaultNode]] {
        if fn.fault.id == self.fault_id {
            visit [fn];
        }
    }
}

# The fault re-evaluates itself from the crew's finding: kind, device, street,
# homes, status and confidence. The walker carries the before/after text back.
impl FaultNode.reevaluate {
    f = self.fault;
    u = visitor.update;
    if u is None or f.id != visitor.fault_id {
        return;
    }
    where_before = f.street if (f.kind == FaultKind.SERVICE_WIRE and f.street != "") else f.device_id;
    before = f.kind.name + "@" + where_before + " (conf " + f"{f.confidence:.1f}" + ")";
    kind = u.new_kind if u.new_kind != FaultKind.UNKNOWN else f.kind;
    device = u.new_device_id if u.new_device_id != "" else f.device_id;
    street = u.street if kind == FaultKind.SERVICE_WIRE else "";
    changed = kind != f.kind or device != f.device_id or street != f.street;
    f.kind = kind;
    f.device_id = device;
    f.street = street;
    if visitor.homes > 0 {
        f.homes_affected = visitor.homes;
    }
    f.confidence = 0.9;
    f.updated_by_crew = True;
    if u.restored {
        f.status = FaultStatus.RESTORED;
        f.eta_min = 0;
    } else {
        if f.status == FaultStatus.SUSPECTED or f.status == FaultStatus.CREW_ASSIGNED {
            f.status = FaultStatus.CONFIRMED;
        }
        if u.repair_eta_min > 0 {
            f.eta_min = u.repair_eta_min;
        }
    }
    if u.note != "" {
        evidence: list[str] = list(f.evidence);
        evidence.append("Crew report: " + u.note);
        f.evidence = evidence;
    }
    where_after = f.street if (f.kind == FaultKind.SERVICE_WIRE and f.street != "") else f.device_id;
    after = f.kind.name + "@" + where_after + " (conf " + f"{f.confidence:.1f}" + ")";
    if changed {
        f.change_note = before + " -> " + after + " - crew report";
    } elif u.restored {
        f.change_note = after + " restored - crew report";
    } else {
        f.change_note = after + " confirmed - crew report";
    }
    self.fault = label_fault(f);    # reassign so the nested changes persist
    visitor.changed = changed;
    visitor.before = before;
    visitor.after = after;
    visitor.result = self.fault;
}
