"""Implementations for OperatorApp component."""

impl OperatorApp.loadInitial -> None {
    g_res = root spawn get_grid();
    if g_res.reports and len(g_res.reports) > 0 {
        cur_grid = g_res.reports[0];
        grid = cur_grid;
        counters = cur_grid.counters;
        clock_min = cur_grid.clock_min;
        running = cur_grid.running;
        speed = cur_grid.speed;
    }

    f_res = root spawn get_faults();
    if f_res.reports {
        cur_faults = f_res.reports;
        faults = cur_faults;
        if len(cur_faults) > 0 and not _sel["id"] and not selected_fault_id {
            selected_fault_id = cur_faults[0].id;
        }
    }

    e_res = root spawn get_events(since_min=0.0);
    if e_res.reports {
        events = e_res.reports;
    }

    c_res = root spawn get_crews();
    if c_res.reports {
        crews = c_res.reports;
    }

    a_res = root spawn get_actions();
    if a_res.reports {
        actions = a_res.reports;
    }
}

impl OperatorApp.handleStartStorm -> None {
    _ = root spawn start_storm(speed=speed, f5=f5_on, scenario=scenario);
    running = True;
    loadInitial();
}

impl OperatorApp.handleReset -> None {
    _ = root spawn reset();
    _sel["id"] = "";
    selected_fault_id = "";
    why_text = "";
    running = False;
    loadInitial();
}

impl OperatorApp.handleTick -> None {
    _ = root spawn tick(minutes=0.5 * speed);
    await loadInitial();
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

impl OperatorApp.loadExplanation -> None {
    res = root spawn explain(fault_id=selected_fault_id);
    if res.reports and len(res.reports) > 0 {
        why_text = res.reports[0].explanation;
        why_id = res.reports[0].id;
    }
}

impl OperatorApp.pollTick -> None {
    _poll["busy"] = True;
    try {
        await handleTick();
    } finally {
        _poll["busy"] = False;
    }
}
