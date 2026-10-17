"""Implementations for OperatorApp component."""

impl OperatorApp.loadInitial -> None {
    g_res = root spawn get_grid();
    if g_res.reports and len(g_res.reports) > 0 {
        grid = g_res.reports[0];
        counters = grid.counters;
        clock_min = grid.clock_min;
        running = grid.running;
        speed = grid.speed;
    }

    f_res = root spawn get_faults();
    faults = f_res.reports;
    if len(faults) > 0 and not selected_fault_id {
        selected_fault_id = faults[0].id;
    }

    e_res = root spawn get_events(since_min=0.0);
    events = e_res.reports;

    c_res = root spawn get_crews();
    crews = c_res.reports;

    a_res = root spawn get_actions();
    actions = a_res.reports;
}

impl OperatorApp.handleStartStorm -> None {
    _ = root spawn start_storm(speed=speed);
    running = True;
    loadInitial();
}

impl OperatorApp.handleReset -> None {
    _ = root spawn reset();
    running = False;
    loadInitial();
}

impl OperatorApp.handleTick -> None {
    _ = root spawn tick(minutes=0.5 * speed);
    loadInitial();
}

impl OperatorApp.handleSubmitCrewReport -> None {
    if not crew_report_text.strip() {
        return;
    }
    _ = root spawn crew_report(crew_id=selected_crew_id, text=crew_report_text.strip());
    crew_report_text = "";
    loadInitial();
}

impl OperatorApp.handleApplyAction(action_id: str) -> None {
    res = root spawn apply_action(action_id=action_id);
    if res.reports and len(res.reports) > 0 {
        action_message = res.reports[0].message;
    }
    loadInitial();
}
