"""Bodies for agents_group.jac."""

def _is_tie(sw: Switch) -> bool {
    return sw.normally_open or sw.kind == "tie";
}

impl build_index -> GridIndex {
    idx = GridIndex();
    seen: set[str] = set();
    queue: list[GridNode] = [n for n in [root -->] if isinstance(n, GridNode)];
    sections: list[Section] = [];
    while len(queue) > 0 {
        n = queue.pop(0);
        if n.id in seen {
            continue;
        }
        seen.add(n.id);
        if isinstance(n, Section) {
            sections.append(n);
            for lm in [n <--] {
                if isinstance(lm, Landmark) and lm.id not in seen {
                    seen.add(lm.id);
                    idx.landmarks.append(lm);
                }
            }
        } elif isinstance(n, Transformer) {
            idx.transformers.append(n);
        } elif isinstance(n, Home) {
            idx.homes[n.id] = n;
            if n.consumer_no != "" {
                idx.homes_by_consumer[n.consumer_no] = n;
            }
        } elif isinstance(n, Landmark) {
            idx.landmarks.append(n);
        }
        for m in children(n) {
            if isinstance(m, GridNode) and m.id not in seen {
                queue.append(m);
            }
        }
    }
    # Radial topology in the NORMAL configuration: switch positions on the day
    # (SW1 locked out) are physical truth, so only tie switches are cut.
    for s in sections {
        idx.tx_of[s.id] = [];
        idx.child_sections[s.id] = [];
    }
    for s in sections {
        for c in children(s) {
            if isinstance(c, Transformer) {
                idx.tx_of[s.id].append(c);
                idx.section_of[c.id] = s.id;
            } elif isinstance(c, Section) {
                idx.child_sections[s.id].append(c.id);
                idx.parent_section[c.id] = s.id;
            } elif isinstance(c, Switch) and not _is_tie(c) {
                for d in children(c) {
                    if isinstance(d, Section) {
                        idx.child_sections[s.id].append(d.id);
                        idx.parent_section[d.id] = s.id;
                    }
                }
            }
        }
    }
    for t in idx.transformers {
        idx.tx_homes[t.id] = [h for h in children(t) if isinstance(h, Home)];
    }
    by_id: dict[str, Section] = {s.id: s for s in sections};
    order: list[str] = [s.id for s in sections if s.id not in idx.parent_section];
    i = 0;
    while i < len(order) {
        order.extend(idx.child_sections[order[i]]);
        i += 1;
    }
    idx.sections = [by_id[sid] for sid in order];
    return idx;
}

impl start_node(c: Complaint, idx: GridIndex) -> GridNode | None {
    if c.is_duplicate {
        return None;
    }
    if c.home_id != "" and c.home_id in idx.homes {
        return idx.homes[c.home_id];
    }
    if c.consumer_no != "" and c.consumer_no in idx.homes_by_consumer {
        return idx.homes_by_consumer[c.consumer_no];
    }
    sid = section_for_landmark(idx, c.landmark);
    for s in idx.sections {
        if s.id == sid {
            return s;
        }
    }
    return None;
}

impl localise(c: Complaint, idx: GridIndex) -> bool {
    n = start_node(c, idx);
    if n is None {
        return False;
    }
    root spawn Localiser(complaint_id=c.id, starts=[n]);
    return True;
}

# Each spawn costs ~0.2 s on the full grid whatever it does, so one walker
# climbs from every start in the batch.
impl localise_all(complaints: list[Complaint]) -> int {
    idx = build_index();
    starts: list[GridNode] = [];
    for c in complaints {
        n = start_node(c, idx);
        if n is not None {
            starts.append(n);
        }
    }
    if len(starts) > 0 {
        root spawn Localiser(starts=starts);
    }
    return len(starts);
}

impl home_count(idx: GridIndex, t: Transformer) -> int {
    if t.homes > 0 {
        return t.homes;
    }
    return len(idx.tx_homes.get(t.id, []));
}

impl ratio(idx: GridIndex, t: Transformer) -> float {
    return t.reports / max(home_count(idx, t), 1);
}

impl subtree_sections(idx: GridIndex, sid: str) -> list[str] {
    out: list[str] = [sid];
    i = 0;
    while i < len(out) {
        out.extend(idx.child_sections.get(out[i], []));
        i += 1;
    }
    return out;
}

# A section "looks de-energised" when every one of its own transformers has
# reports: one dead line silences them all, a blown fuse silences only one.
impl looks_dead(idx: GridIndex, sid: str) -> bool {
    txs = idx.tx_of.get(sid, []);
    if len(txs) == 0 {
        return False;
    }
    for t in txs {
        if ratio(idx, t) < DEAD_RATIO {
            return False;
        }
    }
    return True;
}

def _tx_ids(txs: list[Transformer]) -> list[str] {
    return [t.id for t in txs];
}

def _subtree_tx(idx: GridIndex, secs: list[str]) -> list[Transformer] {
    out: list[Transformer] = [];
    for sid in secs {
        out.extend(idx.tx_of.get(sid, []));
    }
    return out;
}

def _home_tx(idx: GridIndex, c: Complaint) -> str {
    h: Home | None = None;
    if c.home_id != "" and c.home_id in idx.homes {
        h = idx.homes[c.home_id];
    } elif c.consumer_no != "" and c.consumer_no in idx.homes_by_consumer {
        h = idx.homes_by_consumer[c.consumer_no];
    }
    if h is None {
        return "";
    }
    if h.transformer_id != "" {
        return h.transformer_id;
    }
    ups = [p for p in parents(h) if isinstance(p, Transformer)];
    return ups[0].id if len(ups) > 0 else "";
}

# Hazard severity, most severe first.
def _hazard_rank(h: Hazard) -> int {
    match h {
        case Hazard.FIRE:
            return 4;
        case Hazard.WIRE_DOWN:
            return 3;
        case Hazard.SPARKS:
            return 2;
        case Hazard.TRANSFORMER_NOISE:
            return 1;
        case _:
            return 0;
    }
}

# Non-duplicate complaints from homes under `tx_ids` or landmarks on `sec_ids`.
def _complaints_for(
    idx: GridIndex, complaints: list[Complaint], tx_ids: list[str], sec_ids: list[str]
) -> list[Complaint] {
    out: list[Complaint] = [];
    for c in complaints {
        if c.is_duplicate {
            continue;
        }
        tid = _home_tx(idx, c);
        if tid != "" {
            if tid in tx_ids {
                out.append(c);
            }
        } elif section_for_landmark(idx, c.landmark) in sec_ids {
            out.append(c);
        }
    }
    return out;
}

def _make_fault(
    kind: FaultKind,
    device: str,
    homes: int,
    critical: list[str],
    confidence: float,
    evidence: list[str],
    cs: list[Complaint]
) -> Fault {
    worst = Hazard.NONE;
    for c in cs {
        if _hazard_rank(c.hazard) > _hazard_rank(worst) {
            worst = c.hazard;
        }
    }
    first = min([c.time_min for c in cs]) if len(cs) > 0 else 0.0;
    return Fault(
        id="",
        kind=kind,
        device_id=device,
        homes_affected=homes,
        critical_loads=critical,
        hazard=worst,
        confidence=round(confidence, 2),
        evidence=evidence,
        complaint_ids=[c.id for c in cs],
        first_report_min=first
    );
}

def _critical(txs: list[Transformer]) -> list[str] {
    out: list[str] = [];
    for t in txs {
        for load in t.critical {
            if load not in out {
                out.append(load);
            }
        }
    }
    return out;
}

# Only the landmarks the hazard complaints name, not every landmark on `secs`
# (a section can also hold a hospital or school landmark).
def _landmark_names(idx: GridIndex, complaints: list[Complaint], secs: list[str]) -> str {
    names: list[str] = [];
    for c in complaints {
        if c.is_duplicate or c.hazard == Hazard.NONE {
            continue;
        }
        lm = _matched_landmark(idx, c.landmark);
        if lm and lm.section_id in secs and lm.name != "" and lm.name not in names {
            names.append(lm.name);
        }
    }
    return ", ".join(names) if len(names) > 0 else "a landmark";
}

def _line_down(
    idx: GridIndex,
    complaints: list[Complaint],
    sid: str,
    hot: list[Transformer],
    hazards: int,
    dead: bool
) -> Fault {
    secs = subtree_sections(idx, sid);
    txs = _subtree_tx(idx, secs);
    homes = sum([home_count(idx, t) for t in txs]);
    reporting = sum([t.reports for t in txs]);
    hot_ids = ", ".join(_tx_ids(hot));
    evidence: list[str] = [f"{reporting} of {homes} homes downstream of {sid} reported"];
    if len(hot) > 0 {
        evidence.append(f"{len(hot)} transformers downstream of {sid} are out together: {hot_ids}");
    }
    if hazards > 0 {
        where = _landmark_names(idx, complaints, secs);
        evidence.append(f"{hazards} hazard reports mention {where}");
    }
    parent = idx.parent_section.get(sid, "");
    if parent != "" and not looks_dead(idx, parent) {
        evidence.append(f"{parent} upstream still has supply, so the break is at {sid}");
    }
    confidence = 0.5;
    if dead {
        confidence = min(0.95, 0.6 + 0.1 * max(len(hot) - 1, 0) + (0.2 if hazards > 0 else 0.0));
    }
    cs = _complaints_for(idx, complaints, _tx_ids(txs), secs);
    return _make_fault(FaultKind.LINE_DOWN, sid, homes, _critical(txs), confidence, evidence, cs);
}

impl find_candidates(idx: GridIndex, complaints: list[Complaint]) -> list[Fault] {
    cands: list[Fault] = [];
    covered_secs: set[str] = set();
    covered_tx: set[str] = set();
    # Hazard complaints whose landmark maps to a section
    hazard_at: dict[str, int] = {};
    for c in complaints {
        if not c.is_duplicate and c.hazard != Hazard.NONE {
            sid = section_for_landmark(idx, c.landmark);
            if sid != "" {
                hazard_at[sid] = hazard_at.get(sid, 0) + 1;
            }
        }
    }
    # Step 2: LINE_DOWN at the most upstream de-energised-looking section whose
    # subtree holds >= 2 hot transformers or a hazard landmark.
    for s in idx.sections {
        if s.id in covered_secs {
            continue;
        }
        secs = subtree_sections(idx, s.id);
        hot = [t for t in _subtree_tx(idx, secs) if ratio(idx, t) >= HOT_RATIO];
        hazards = sum([hazard_at.get(x, 0) for x in secs]);
        if looks_dead(idx, s.id) and (len(hot) >= 2 or hazards > 0) {
            cands.append(_line_down(idx, complaints, s.id, hot, hazards, True));
            covered_secs.update(secs);
            covered_tx.update(_tx_ids(_subtree_tx(idx, secs)));
        }
    }
    # A hazard on a section that does not look dead yet is still a line fault.
    for s in idx.sections {
        if s.id in hazard_at and s.id not in covered_secs {
            secs = subtree_sections(idx, s.id);
            hot = [t for t in _subtree_tx(idx, secs) if ratio(idx, t) >= HOT_RATIO];
            cands.append(_line_down(idx, complaints, s.id, hot, hazard_at[s.id], False));
            covered_secs.update(secs);
            covered_tx.update(_tx_ids(_subtree_tx(idx, secs)));
        }
    }
    for t in idx.transformers {
        if t.id in covered_tx or t.reports == 0 {
            continue;
        }
        r = ratio(idx, t);
        homes = home_count(idx, t);
        pct = int(round(r * 100));
        sid = idx.section_of.get(t.id, "");
        cs = _complaints_for(idx, complaints, [t.id], []);
        # Step 3: transformer fuse
        if r >= FUSE_RATIO {
            evidence = [f"{t.reports} of {homes} homes on {t.id} reported ({pct}%)"];
            if sid != "" {
                evidence.append(f"Other transformers on {sid} have supply, so only {t.id} is out");
            }
            cands.append(
                _make_fault(FaultKind.TX_FUSE, t.id, homes, _critical([t]), min(0.9, 0.5 + r), evidence, cs)
            );
            continue;
        }
        # Step 4: few reports, mostly from one street -> low-confidence fuse
        if r >= STREET_MIN_RATIO {
            by_street: dict[str, int] = {};
            for h in idx.tx_homes.get(t.id, []) {
                if h.reported {
                    by_street[h.street] = by_street.get(h.street, 0) + 1;
                }
            }
            top = "";
            top_n = 0;
            for (street, n) in by_street.items() {
                if n > top_n {
                    top = street;
                    top_n = n;
                }
            }
            total = sum(list(by_street.values()));
            if total > 0 and top_n / total >= STREET_SHARE {
                evidence = [
                    f"{t.reports} of {homes} homes on {t.id} reported ({pct}%)",
                    f"{top_n} of {total} reports come from {top}",
                    f"Low confidence: a fuse at {t.id} or a service wire on {top}"
                ];
                cands.append(
                    _make_fault(
                        FaultKind.TX_FUSE, t.id, homes, _critical([t]), STREET_CONFIDENCE, evidence, cs
                    )
                );
            }
        }
        # Step 5: anything else is an isolated / possibly false report: no fault.
    }
    return cands;
}

def _all_complaints -> list[Complaint] {
    out: list[Complaint] = [];
    for log in [root -->[?:ComplaintLog]] {
        out.extend([fix_complaint(c) for c in log.items]);
    }
    return out;
}

def _next_fault_id -> str {
    states = [root -->[?:SimState]];
    if len(states) == 0 {
        states = root ++> SimState();
    }
    st = states[0];
    n = st.next_fault_no;
    st.next_fault_no = n + 1;
    return f"FLT-{n:03d}";
}

def _overlaps(a: list[str], b: list[str]) -> bool {
    bs = set(b);
    for x in a {
        if x in bs {
            return True;
        }
    }
    return False;
}

def _closed(f: Fault) -> bool {
    return f.status == FaultStatus.RESTORED or f.status == FaultStatus.CLOSED;
}

# Copy a candidate into an existing FaultNode, keeping id, status, priority
# and crew fields. A crew-corrected or finished fault is never rewritten.
def _update(fn: FaultNode, c: Fault) {
    old = fn.fault;
    if _closed(old) {
        return;
    }
    if old.updated_by_crew {
        ids = list(old.complaint_ids);
        for cid in c.complaint_ids {
            if cid not in ids {
                ids.append(cid);
            }
        }
        old.complaint_ids = ids;
        fn.fault = old;
        return;
    }
    same = old.kind == c.kind and old.device_id == c.device_id;
    fn.fault = label_fault(
        Fault(
            id=old.id,
            kind=c.kind,
            device_id=c.device_id,
            homes_affected=c.homes_affected,
            street=c.street,
            critical_loads=c.critical_loads,
            hazard=c.hazard,
            priority=old.priority,
            confidence=c.confidence if old.status == FaultStatus.SUSPECTED else max(old.confidence, c.confidence),
            status=old.status,
            evidence=c.evidence,
            complaint_ids=c.complaint_ids,
            first_report_min=c.first_report_min,
            crew_id=old.crew_id,
            eta_min=old.eta_min,
            updated_by_crew=old.updated_by_crew,
            change_note=old.change_note,
            explanation=old.explanation if same else ""
        )
    );
}

impl group_faults(complaints: list[Complaint] | None = None) -> list[Fault] {
    cs = complaints if complaints is not None else _all_complaints();
    idx = build_index();
    cands = find_candidates(idx, cs);
    existing = [root -->[?:FaultNode]];
    matched: set[str] = set();
    pending: list[Fault] = [];
    # 1. Same kind at the same device: refresh it.
    for c in cands {
        hit = False;
        for fn in existing {
            if fn.fault.id not in matched and fn.fault.kind == c.kind and fn.fault.device_id == c.device_id {
                matched.add(fn.fault.id);
                _update(fn, c);
                hit = True;
                break;
            }
        }
        if not hit {
            pending.append(c);
        }
    }
    # 2. A crew already corrected this fault (e.g. F4 -> SERVICE_WIRE): the
    #    crew's finding wins, so the old guess is not re-created beside it.
    rest: list[Fault] = [];
    for c in pending {
        hit = False;
        for fn in existing {
            if fn.fault.id not in matched and fn.fault.updated_by_crew and _overlaps(c.complaint_ids, fn.fault.complaint_ids) {
                matched.add(fn.fault.id);
                _update(fn, c);
                hit = True;
                break;
            }
        }
        if not hit {
            rest.append(c);
        }
    }
    # 3. More evidence moved a suspected fault (TX_FUSE@T3 -> LINE_DOWN@F1-B):
    #    reuse its node and id. 4. Otherwise it is a new fault.
    for c in rest {
        hit = False;
        for fn in existing {
            if fn.fault.id not in matched and not fn.fault.updated_by_crew and not _closed(fn.fault) and _overlaps(c.complaint_ids, fn.fault.complaint_ids) {
                matched.add(fn.fault.id);
                _update(fn, c);
                hit = True;
                break;
            }
        }
        if not hit {
            c.id = _next_fault_id();
            root ++> FaultNode(fault=label_fault(c));
        }
    }
    # Suspected, unassigned faults the evidence no longer supports are dropped.
    for fn in existing {
        f = fn.fault;
        if f.id not in matched and f.status == FaultStatus.SUSPECTED and f.crew_id == "" and not f.updated_by_crew {
            del fn;
        }
    }
    return [fn.fault for fn in [root -->[?:FaultNode]]];
}

impl section_for_landmark(idx: GridIndex, text: str) -> str {
    if text == "" {
        return "";
    }
    if text not in idx.landmark_of {
        idx.landmark_of[text] = _match_landmark(idx, text);
    }
    return idx.landmark_of[text];
}

# Same matching rules as agents_parse.landmark_section, but over the landmarks
# this index already holds: that function walks the whole grid on every call
# (~7 s under jac test), too slow to call per complaint inside a tick.
def _match_landmark(idx: GridIndex, text: str) -> str {
    lm = _matched_landmark(idx, text);
    return lm.section_id if lm else "";
}

def _matched_landmark(idx: GridIndex, text: str) -> Landmark | None {
    t = " " + " ".join(re.findall(r"[a-z0-9]+", text.lower())) + " ";
    if t.strip() == "" {
        return None;
    }
    for lm in idx.landmarks {
        name = " ".join(re.findall(r"[a-z0-9]+", lm.name.lower()));
        if name and (" " + name + " ") in t {
            return lm;
        }
        # "pole 23" also matches "pole no 23", "pole #23" and "kanuwa 23"
        digits = re.findall(r"\d+", name);
        if digits and ("pole" in name) {
            num: str = str(digits[0]);
            pattern: str = r"(pole|kanuwa|කණුව)\D{0,6}" + num + r"(?!\d)";
            if re.search(pattern, text.lower()) {
                return lm;
            }
        }
    }
    return None;
}
