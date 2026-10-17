"""Bodies for sim.jac."""

# ------------------------------------------------------------- state access
impl sim_state -> SimState {
    found = [root -->[?:SimState]];
    return found[0] if found else (root ++> SimState())[0] as SimState;
}

impl event_log -> EventLog {
    found = [root -->[?:EventLog]];
    return found[0] if found else (root ++> EventLog())[0] as EventLog;
}

impl complaint_log -> ComplaintLog {
    found = [root -->[?:ComplaintLog]];
    return found[0] if found else (root ++> ComplaintLog())[0] as ComplaintLog;
}

impl action_store -> ActionStore {
    found = [root -->[?:ActionStore]];
    return found[0] if found else (root ++> ActionStore())[0] as ActionStore;
}

impl ensure_grid -> Substation {
    return build_grid();
}

impl clock -> float {
    return sim_state().clock_min;
}

impl log_event(kind: str, text: str, fault_id: str = "") {
    log = event_log();
    events: list[Event] = list(log.events);
    events.append(Event(time_min=float(f"{clock():.1f}"), kind=kind, text=text, fault_id=fault_id));
    log.events = events;    # reassign so the change persists
}

# ---------------------------------------------------------------- helpers
impl _scenario -> list[Complaint] {
    name = _active_scenario();
    if name not in _SCENARIOS {
        raw: list[Complaint] = generate_complaints(STORM_SEED);
        if name == "blackout" {
            raw = blackout_complaints();
        } elif name == "island" {
            raw = island_complaints();
        }
        _SCENARIOS[name] = sorted(raw, key=lambda c: Complaint : c.time_min);
    }
    return _SCENARIOS[name];
}

# The scenario this sim applied, read back from the truth it set, so it
# survives a server restart mid-run: a tripped TL1 means a blackout. The
# island-wide one trips TL1 too, so its start event tells them apart.
impl _active_scenario -> str {
    for tl in [root -->[?:TransmissionLine]] {
        if not tl.line_ok {
            for e in event_log().events {
                if e.kind == "storm" and e.text.startswith("Island-wide blackout") {
                    return "island";
                }
            }
            return "blackout";
        }
    }
    return "storm";
}

# Released complaints are fresh objects: the parser mutates them, and the
# cached scenario must stay raw for the next replay.
impl _copy(c: Complaint) -> Complaint {
    return Complaint(id=c.id, text=c.text, time_min=c.time_min, consumer_no=c.consumer_no);
}

impl _fault_key(f: Fault) -> str {
    return f"{f.id}";
}

impl _all_grid_nodes -> list[GridNode] {
    seen: set[str] = set();
    out: list[GridNode] = [];
    queue: list[GridNode] = [s for s in [root -->[?:Substation]]];
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

# Ids of the home's transformer and every section/switch above it.
impl _upstream_ids(h: Home) -> list[str] {
    ids: list[str] = [];
    seen: set[str] = set();
    queue: list[GridNode] = parents(h);
    while queue {
        n = queue.pop(0);
        if n.id in seen {
            continue;
        }
        seen.add(n.id);
        ids.append(n.id);
        if isinstance(n, Switch) and n.kind == "tie" {
            continue;    # don't climb into the other feeder
        }
        queue.extend(parents(n));
    }
    return ids;
}

impl _clear_storm {
    for fn in [root -->[?:FaultNode]] {
        del fn;
    }
    event_log().events = [];
    complaint_log().items = [];
    action_store().actions = [];
    st = sim_state();
    st.clock_min = 0.0;
    st.running = False;
    st.next_complaint_idx = 0;
    st.next_fault_no = 1;
    st.next_complaint_no = 1;
    reset_grid();
}

# ---------------------------------------------------------------- pipeline
impl storm_start(speed: int, scenario: str = "storm") -> Ack {
    ensure_grid();
    _clear_storm();
    st = sim_state();
    island: bool = scenario == "island";
    blackout: bool = scenario == "blackout" or island;
    if blackout {
        apply_blackout_truth();
    } else {
        apply_storm_truth(st.f5_enabled);
    }
    st.running = True;
    st.speed = max(1, speed);
    run_energiser();
    run_restorer();
    if island {
        # Logged before _scenario(), which reads it to pick the island flood.
        log_event("storm", f"Island-wide blackout started at {st.speed}x: the national grid is down");
        n_island = len(_scenario());
        log_event("storm", f"{n_island} complaints will arrive over {int(ISLAND_LENGTH_MIN)} minutes");
        return Ack(ok=True, message=f"Island-wide blackout started at {st.speed}x", clock_min=st.clock_min);
    }
    n = len(_scenario());
    if blackout {
        log_event("storm", f"Blackout started at {st.speed}x: {n} complaints will arrive over {int(BLACKOUT_LENGTH_MIN)} minutes");
        return Ack(ok=True, message=f"Blackout started at {st.speed}x", clock_min=st.clock_min);
    }
    log_event("storm", f"Storm started at {st.speed}x: {n} complaints will arrive over {int(STORM_LENGTH_MIN)} minutes");
    return Ack(ok=True, message=f"Storm started at {st.speed}x", clock_min=st.clock_min);
}

impl storm_tick(minutes: float) -> Ack {
    st = sim_state();
    if not st.running {
        return Ack(ok=True, message="No storm running", clock_min=st.clock_min);
    }
    # 1. advance the clock
    st.clock_min = float(f"{st.clock_min + max(0.0, minutes):.2f}");
    # 2. release due complaints
    scenario = _scenario();
    released: list[Complaint] = [];
    i: int = st.next_complaint_idx;
    while i < len(scenario) and scenario[i].time_min <= st.clock_min {
        released.append(_copy(scenario[i]));
        i += 1;
    }
    st.next_complaint_idx = i;
    # 3-6, 8
    if released {
        process_complaints(released);
    }
    # 7. C's walkers (no-ops until WP-C3 / WP-C4)
    drain_microgrids(minutes);
    run_energiser();
    run_dispatcher(minutes);
    run_restorer();
    left: int = len(scenario) - st.next_complaint_idx;
    return Ack(ok=True, message=f"{len(released)} new complaints, {left} still to come", clock_min=st.clock_min);
}

impl process_complaints(new_items: list[Complaint]) -> int {
    log = complaint_log();
    earlier: list[Complaint] = list(log.items);
    # 3. parse (BD regex, cache, batched LLM) and flag duplicates
    parse_batch(new_items);
    flag_duplicates(new_items, earlier);
    for c in new_items {
        label_complaint(c);
    }
    log.items = earlier + new_items;
    dups: list[Complaint] = [c for c in new_items if c.is_duplicate];
    for d in dups {
        log_event("duplicate", f"{d.id} repeats an earlier complaint from {d.consumer_no}: not counted again");
    }
    hazards: list[Complaint] = [c for c in new_items if c.hazard_label != ""];
    for h in hazards {
        where_: str = f" near {h.landmark}" if h.landmark else "";
        log_event("complaint", f"{h.id}: hazard reported ({h.hazard_label}){where_}");
    }
    # 4. localise every new non-duplicate complaint
    located: int = localise_all([c for c in new_items if not c.is_duplicate]);
    log_event("complaint", f"{len(new_items)} complaint(s) received, {located} traced upstream");
    # 5-6. group into faults, then rank
    before: dict[str, str] = {};
    for fn in [root -->[?:FaultNode]] {
        before[_fault_key(fn.fault)] = f"{fn.fault.kind_label}@{fn.fault.device_id}";
    }
    group_faults(log.items);
    ranked = rank_fault_nodes(clock());
    # 8. events for new or changed faults
    for f in ranked {
        k = _fault_key(f);
        now: str = f"{f.kind_label}@{f.device_id}";
        if k not in before {
            log_event("fault_new", f"{f.id}: {now} suspected, {f.homes_affected} homes, confidence {f.confidence:.1f}", f.id);
        } elif before[k] != now {
            log_event("fault_update", f"{f.id}: {before[k]} -> {now}", f.id);
        }
    }
    return located;
}

impl submit(text: str, consumer_no: str) -> Complaint {
    ensure_grid();
    st = sim_state();
    c = Complaint(id=f"U{st.next_complaint_no:04d}", text=text, time_min=st.clock_min, consumer_no=consumer_no);
    st.next_complaint_no += 1;
    log = complaint_log();
    earlier: list[Complaint] = list(log.items);
    parse_one(c);
    flag_duplicates([c], earlier);
    label_complaint(c);
    log.items = earlier + [c];
    if c.is_duplicate {
        log_event("duplicate", f"{c.id} repeats an earlier complaint from {c.consumer_no}: not counted again");
        return c;
    }
    log_event("complaint", f"{c.id} submitted on the customer page");
    localise_all([c]);
    group_faults(log.items);
    rank_fault_nodes(st.clock_min);
    return c;
}

impl storm_reset -> Ack {
    ensure_grid();
    _clear_storm();
    run_energiser();
    run_restorer();
    log_event("reset", "Grid restored to normal; storm cleared");
    return Ack(ok=True, message="Reset to normal grid", clock_min=0.0);
}

impl run_energiser {
    subs = [root -->[?:Substation]];
    if subs {
        subs[0] spawn Energiser();
    }
}

impl run_dispatcher(minutes: float) {
    root spawn Dispatcher(clock_min=clock(), minutes=minutes);
}

impl run_restorer {
    root spawn Restorer();
}

# Islanded microgrids burn battery with the simulated clock; a flat one stops
# supplying (the Energiser then re-evaluates the load).
impl drain_microgrids(minutes: float) {
    for n in _all_grid_nodes() {
        if isinstance(n, Microgrid) and n.supplying {
            n.battery_min = max(0, n.battery_min - int(round(minutes)));
            if n.battery_min <= 0 {
                n.islanded = False;
                log_event("microgrid", f"{n.id} battery is flat: {n.name} has stopped supplying");
            }
        }
    }
}

# ------------------------------------------------------------------- reads
impl ranked_faults -> list[Fault] {
    return rank_fault_nodes(clock());
}

impl complaints_since(since_min: float) -> list[Complaint] {
    return [c for c in complaint_log().items if c.time_min >= since_min];
}

impl events_since(since_min: float) -> list[Event] {
    return [e for e in event_log().events if e.time_min >= since_min];
}

impl crews -> list[Crew] {
    return [label_crew(cn.crew) for cn in [root -->[?:CrewNode]]];
}

impl tasks -> list[CrewTask] {
    out: list[CrewTask] = [];
    for c in crews() {
        if c.task_fault_id {
            out.append(CrewTask(crew_id=c.id, fault_id=c.task_fault_id, eta_min=c.eta_min, status_label=c.status_label));
        }
    }
    return out;
}

impl actions -> list[Action] {
    return list(action_store().actions);
}

# Applies a safe action's switching steps, then re-runs the Energiser.
# WP-C7 owns how actions are built and checked; this only executes them.
impl apply(action_id: str) -> ActionResult {
    store = action_store();
    acts: list[Action] = list(store.actions);
    for a in acts {
        if a.id != action_id {
            continue;
        }
        if not a.safe {
            log_event("action_blocked", f"{a.id} blocked: {a.reason}");
            return ActionResult(ok=False, message=a.reason, action=a, counters=counters());
        }
        switches: dict[str, Switch] = {};
        mgs: dict[str, Microgrid] = {};
        for n in _all_grid_nodes() {
            if isinstance(n, Switch) {
                switches[n.id] = n;
            } elif isinstance(n, Microgrid) {
                mgs[n.id] = n;
            }
        }
        for s in a.steps {
            if s.switch_id in switches {
                switches[s.switch_id].closed = s.action == "close";
            } elif s.switch_id.endswith("-ISO") and s.switch_id[:-4] in mgs {
                mgs[s.switch_id[:-4]].isolated = s.action == "open";    # open = isolated
            } elif s.switch_id in mgs {
                mgs[s.switch_id].islanded = s.action == "close";
            }
        }
        a.applied = True;
        store.actions = acts;
        run_energiser();
        run_restorer();
        log_event("action_applied", f"{a.id} applied: {a.reason}" if a.kind == "microgrid" else f"{a.id} applied: {a.homes_restored} homes restored");
        return ActionResult(ok=True, message=f"Applied {a.id}: {a.homes_restored} homes restored", action=a, counters=counters());
    }
    return ActionResult(ok=False, message=f"No action {action_id}");
}

impl counters -> Counters {
    homes_off: int = 0;
    for n in _all_grid_nodes() {
        if isinstance(n, Home) and not n.has_power {
            homes_off += 1;
        }
    }
    active: int = 0;
    restored: int = 0;
    for fn in [root -->[?:FaultNode]] {
        if is_finished(fn.fault) {
            restored += fn.fault.homes_affected;
        } else {
            active += 1;
        }
    }
    return Counters(
        complaints=len(complaint_log().items), faults=active,
        homes_off=homes_off, homes_restored=restored
    );
}

impl grid_view -> GridView {
    ss = ensure_grid();
    snap = Snapshot();
    ss spawn snap;
    nodes: list[GridNodeView] = list(snap.nodes);
    # Fault state colours the faulted device: suspected / faulted / restored
    state_of: dict[str, str] = {};
    for fn in [root -->[?:FaultNode]] {
        f = fn.fault;
        colour: str = "suspected";
        if is_finished(f) {
            colour = "restored";
        } elif f.status != FaultStatus.SUSPECTED {
            colour = "faulted";
        }
        state_of[f.device_id] = colour;
    }
    for v in nodes {
        if v.id in state_of {
            v.status = state_of[v.id];
        }
    }
    edges: list[GridEdgeView] = list(snap.edges);
    for tl in [root -->[?:TransmissionLine]] {
        nodes.append(GridNodeView(id=tl.id, kind="transmission", x=tl.x, y=tl.y, label=f"{tl.id} · {tl.kv} kV", energised=tl.energised, has_power=tl.energised, status=state_of.get(tl.id, "normal")));
        for ss in [x for x in [tl -->] if isinstance(x, Substation)] {
            edges.append(GridEdgeView(from_id=tl.id, to_id=ss.id, kind="transmission"));
        }
    }
    for d in [root -->[?:Depot]] {
        nodes.append(GridNodeView(id=d.id, kind="depot", x=d.x, y=d.y, label=d.name or d.id));
    }
    # Landmarks hang off root or point at their Section with a Located edge
    # (grid_build does the latter), so look in both places.
    marks: dict[str, Landmark] = {};
    for lm in [root -->[?:Landmark]] {
        marks[lm.id] = lm;
    }
    for n in _all_grid_nodes() {
        if isinstance(n, Section) {
            for x in [n <--] {
                if isinstance(x, Landmark) {
                    marks[x.id] = x;
                }
            }
        }
    }
    for lm in marks.values() {
        nodes.append(GridNodeView(id=lm.id, kind="landmark", x=lm.x, y=lm.y, label=lm.name, parent_id=lm.section_id, has_power=lm.energised, status=state_of.get(lm.section_id, "normal")));
    }
    for c in crews() {
        nodes.append(GridNodeView(id=c.id, kind="crew", x=c.x, y=c.y, label=c.name or c.id, status=c.status_label));
    }
    st = sim_state();
    return GridView(nodes=nodes, edges=edges, clock_min=st.clock_min, counters=counters(), running=st.running, speed=st.speed);
}

impl crew_fault(crew_id: str) -> Fault | None {
    for c in crews() {
        if c.id == crew_id and c.task_fault_id {
            for fn in [root -->[?:FaultNode]] {
                if fn.fault.id == c.task_fault_id {
                    return label_fault(fn.fault);
                }
            }
        }
    }
    return None;
}

impl customer_status(consumer_no: str) -> CustomerStatus {
    log_event("status_checked", f"Status checked for {consumer_no}");
    home: Home | None = None;
    for n in _all_grid_nodes() {
        if isinstance(n, Home) and n.consumer_no == consumer_no {
            home = n;
            break;
        }
    }
    if home is None {
        return CustomerStatus(consumer_no=consumer_no, has_power=True, status_text="Consumer number not found. Please check the number on your bill.");
    }
    up = _upstream_ids(home);
    street: str = home.street;
    found: list[Fault] = [
        fn.fault for fn in [root -->[?:FaultNode]]
        if fn.fault.device_id in up and (fn.fault.street == "" or fn.fault.street == street)
    ];
    if not found {
        if home.has_power {
            return CustomerStatus(consumer_no=consumer_no, has_power=True, status_text="Power is on in your area.");
        }
        return CustomerStatus(consumer_no=consumer_no, has_power=False, status_text="Your report is received. We are locating the fault.");
    }
    f: Fault = sorted(found, key=lambda x: Fault : -x.priority)[0];
    if is_finished(f) {
        return CustomerStatus(consumer_no=consumer_no, has_power=home.has_power, fault_id=f.id, status_text="Power restored. Thank you for your patience.");
    }
    crew_name: str = "";
    for c in crews() {
        if c.id == f.crew_id {
            crew_name = c.name or c.id;
        }
    }
    text: str = "Fault found - we are assigning a crew.";
    if crew_name and f.status == FaultStatus.CREW_ASSIGNED {
        text = f"Fault found - {crew_name} on the way - ETA {f.eta_min} min";
    } elif crew_name {
        text = f"Fault found - {crew_name} is working on it";
    }
    return CustomerStatus(consumer_no=consumer_no, has_power=home.has_power, fault_id=f.id, eta_min=f.eta_min, status_text=text);
}
