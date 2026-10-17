"""SafetyCheck step + Switch guard (WP-C7, CLAUDE.md §8.8).

The walker's inline `gate` (grid.jac) disengages once blocked_by is set.
Switch.guard sets visitor.blocked_by and visitor.reason if closing the switch
would energise a section marked as a work_zone where crews are active.
"""

def _all_switches -> dict[str, Switch] {
    subs = [root -->[?:Substation]];
    if not subs {
        return {};
    }
    seen: set[str] = set();
    switches: dict[str, Switch] = {};
    q: list[GridNode] = [subs[0]];
    while q {
        curr = q.pop(0);
        if curr.id in seen {
            continue;
        }
        seen.add(curr.id);
        if isinstance(curr, Switch) {
            switches[curr.id] = curr as Switch;
        }
        q.extend(children(curr));
    }
    return switches;
}

def _find_switch(sid: str) -> Switch | None {
    return _all_switches().get(sid);
}

def _check_switch_safety(sw: Switch, sc: SafetyCheck) {
    step_found = False;
    step_num = 1;
    for (idx, st) in enumerate(sc.steps) {
        if st.switch_id == sw.id and st.action == "close" {
            step_found = True;
            step_num = idx + 1;
            break;
        }
    }
    if not step_found {
        return;
    }

    all_sw = _all_switches();
    sim_states: dict[str, bool] = {};
    for (sw_id, sw_node) in all_sw.items() {
        sim_states[sw_id] = sw_node.closed;
    }

    for st in sc.steps {
        sim_states[st.switch_id] = (st.action == "close");
        if st.switch_id == sw.id {
            break;
        }
    }

    subs = [root -->[?:Substation]];
    if not subs {
        return;
    }

    seen: set[str] = set();
    q: list[GridNode] = [subs[0]];
    wz_found: list[Section] = [];

    while q {
        curr = q.pop(0);
        if curr.id in seen {
            continue;
        }
        seen.add(curr.id);

        if isinstance(curr, Section) {
            sec = curr as Section;
            if sec.work_zone {
                wz_found.append(sec);
            }
        }

        nbrs = children(curr) + parents(curr);
        for nxt in nbrs {
            if nxt.id in seen {
                continue;
            }
            if isinstance(nxt, Switch) {
                is_closed = sim_states.get(nxt.id, (nxt as Switch).closed);
                if is_closed {
                    q.append(nxt);
                }
            } elif isinstance(nxt, Section) {
                q.append(nxt);
            }
        }
    }

    if wz_found {
        wz = wz_found[0];
        crew_name = "Crew A";
        for cn in [root -->[?:CrewNode]] {
            c = cn.crew;
            if c.location_id == wz.id or c.task_fault_id != "" {
                crew_name = c.name or c.id;
                break;
            }
        }
        sc.blocked_by = sw.id;
        sc.safe = False;
        sc.reason = f"Step {step_num} energises work zone {wz.id} where {crew_name} is working";
    }
}

impl Switch.guard {
    _check_switch_safety(self, visitor);
}

impl SafetyCheck.step {
    if self.blocked_by != "" {
        self.safe = False;
        return;
    }

    if isinstance(here, Switch) {
        _check_switch_safety(here as Switch, self);
        if self.blocked_by != "" {
            self.safe = False;
            return;
        }
    }

    for st in self.steps {
        sw = _find_switch(st.switch_id);
        if sw {
            _check_switch_safety(sw, self);
            if self.blocked_by != "" {
                self.safe = False;
                return;
            }
        }
    }

    self.safe = True;
}
