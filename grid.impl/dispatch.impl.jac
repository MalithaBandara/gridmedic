"""Dispatcher + crew movement (WP-C4, CLAUDE.md §8.5, PLAN.md §5 WP-C4).

Assigns highest-priority unassigned faults to nearest idle crews using the travel table.
Advances crew movement and ETAs with the simulation clock.
When a crew arrives on site at a LINE_DOWN section, marks section work_zone = True.
When faults are restored, releases on-site crews to take next tasks directly.
"""

import from gm_types { CrewStatus, FaultStatus, label_crew, label_fault }

glob DISPATCH_TRACKER: dict[str, dict[str, Any]] = {};

def _device_area(device_id: str) -> str {
    if device_id.startswith("F1") or device_id in ["T1", "T2", "T3", "T4", "T5"] {
        return "North";
    }
    if device_id.startswith("F2") or device_id in ["T6", "T7", "T8", "T9", "T10"] {
        return "South";
    }
    return "North";
}

def _travel_time(crew_location: str, target_device: str) -> int {
    target_area = _device_area(target_device);
    if crew_location == "CSC-North" {
        return 8 if target_area == "North" else 18;
    }
    if crew_location == "CSC-South" {
        return 8 if target_area == "South" else 18;
    }
    crew_area = _device_area(crew_location);
    if crew_area == target_area {
        return 5;
    } else {
        return 15;
    }
}

def _find_grid_node(target_id: str) -> GridNode | None {
    subs = [root -->[?:Substation]];
    if not subs {
        return None;
    }
    seen: set[str] = set();
    q: list[GridNode] = [subs[0]];
    while q {
        curr = q.pop(0);
        if curr.id == target_id {
            return curr;
        }
        if curr.id in seen {
            continue;
        }
        seen.add(curr.id);
        q.extend(children(curr));
    }
    return None;
}

impl Dispatcher.run {
    crew_nodes: list[CrewNode] = [root -->[?:CrewNode]];
    fault_nodes: list[FaultNode] = [root -->[?:FaultNode]];
    event_logs: list[EventLog] = [root -->[?:EventLog]];
    elog = event_logs[0] if event_logs else None;

    # If simulation is at start or all idle, clear tracker
    if self.clock_min <= 0.0 {
        DISPATCH_TRACKER.clear();
    }

    # 1. Update travelling crews and handle arrivals
    for cn in crew_nodes {
        c = cn.crew;
        if c.status == CrewStatus.TRAVELLING {
            # Recall a crew whose fault was dropped or closed on the way, e.g.
            # an early fuse guess that a transmission fault then explained.
            open_task = [fn for fn in fault_nodes if fn.fault.id == c.task_fault_id and fn.fault.status not in [FaultStatus.RESTORED, FaultStatus.CLOSED]];
            if not open_task {
                if elog {
                    elog.events.append(Event(
                        time_min=self.clock_min,
                        kind="crew_recalled",
                        text=f"{c.name or c.id} recalled: {c.task_fault_id} is no longer an open fault",
                        fault_id=c.task_fault_id
                    ));
                }
                c.status = CrewStatus.IDLE;
                c.task_fault_id = "";
                c.eta_min = 0;
                label_crew(c);
                if c.id in DISPATCH_TRACKER {
                    del DISPATCH_TRACKER[c.id];
                }
                continue;
            }
            info = DISPATCH_TRACKER.get(c.id);
            if info is None {
                arr = self.clock_min + float(c.eta_min);
                info = {
                    "fault_id": c.task_fault_id,
                    "device_id": c.location_id,
                    "start_min": self.clock_min,
                    "arrival_min": arr,
                    "start_x": c.x,
                    "start_y": c.y,
                    "target_x": c.x,
                    "target_y": c.y
                };
                DISPATCH_TRACKER[c.id] = info;
            }
            arrival_min: float = float(info["arrival_min"]);
            start_min: float = float(info["start_min"]);
            target_x: int = int(info["target_x"]);
            target_y: int = int(info["target_y"]);
            start_x: int = int(info["start_x"]);
            start_y: int = int(info["start_y"]);
            target_dev: str = str(info["device_id"]);

            if self.clock_min >= arrival_min {
                # Arrived on site!
                c.status = CrewStatus.ON_SITE;
                c.eta_min = 0;
                c.x = target_x;
                c.y = target_y;
                c.location_id = target_dev;
                label_crew(c);

                # Update assigned fault
                for fn in fault_nodes {
                    if fn.fault.id == c.task_fault_id {
                        fn.fault.eta_min = 0;
                        if fn.fault.status == FaultStatus.CREW_ASSIGNED {
                            fn.fault.status = FaultStatus.CONFIRMED;
                        }
                        label_fault(fn.fault);
                    }
                }

                # If LINE_DOWN section, mark work_zone = True
                dev_node = _find_grid_node(target_dev);
                if dev_node and isinstance(dev_node, Section) {
                    (dev_node as Section).work_zone = True;
                }

                if elog {
                    elog.events.append(Event(
                        time_min=self.clock_min,
                        kind="crew_on_site",
                        text=f"{c.name or c.id} arrived on site at {target_dev}",
                        fault_id=c.task_fault_id
                    ));
                }
                if c.id in DISPATCH_TRACKER {
                    del DISPATCH_TRACKER[c.id];
                }
            } else {
                # Still travelling
                rem = max(1, int(round(arrival_min - self.clock_min)));
                c.eta_min = rem;
                label_crew(c);
                for fn in fault_nodes {
                    if fn.fault.id == c.task_fault_id {
                        fn.fault.eta_min = rem;
                        label_fault(fn.fault);
                    }
                }
                total_dur = arrival_min - start_min;
                elapsed = self.clock_min - start_min;
                prog = min(1.0, max(0.0, elapsed / total_dur)) if total_dur > 0.0 else 1.0;
                c.x = int(start_x + prog * (target_x - start_x));
                c.y = int(start_y + prog * (target_y - start_y));
            }
        } elif c.status == CrewStatus.ON_SITE {
            # Check if fault was resolved/restored
            task_fault: Fault | None = None;
            for fn in fault_nodes {
                if fn.fault.id == c.task_fault_id {
                    task_fault = fn.fault;
                }
            }
            is_done = False;
            if task_fault is None {
                is_done = True;
            } elif (task_fault as Fault).status in [FaultStatus.RESTORED, FaultStatus.CLOSED] {
                is_done = True;
            }

            if is_done {
                # Finished work on site, clear work_zone if section
                dev_node = _find_grid_node(c.location_id);
                if dev_node and isinstance(dev_node, Section) {
                    (dev_node as Section).work_zone = False;
                }
                c.status = CrewStatus.IDLE;
                c.task_fault_id = "";
                c.eta_min = 0;
                label_crew(c);
            }
        }
    }

    # 2. Assign idle crews to highest-priority unassigned faults
    unassigned: list[FaultNode] = [];
    for fn in fault_nodes {
        f = fn.fault;
        # A transmission fault is upstream of the substation: no distribution
        # crew can fix it, so none is sent.
        if f.kind == FaultKind.TRANSMISSION {
            continue;
        }
        if f.status not in [FaultStatus.RESTORED, FaultStatus.CLOSED] and (f.crew_id == "" or f.status == FaultStatus.SUSPECTED) {
            unassigned.append(fn);
        }
    }
    unassigned.sort(key=lambda fn: fn.fault.priority, reverse=True);

    for fn in unassigned {
        f = fn.fault;
        idle_crews = [cn for cn in crew_nodes if cn.crew.status == CrewStatus.IDLE];
        if not idle_crews {
            break;
        }

        # Pick nearest idle crew
        best_cn: CrewNode = idle_crews[0];
        best_tt: int = _travel_time(best_cn.crew.location_id, f.device_id);
        for cand in idle_crews[1:] {
            tt = _travel_time(cand.crew.location_id, f.device_id);
            if tt < best_tt {
                best_tt = tt;
                best_cn = cand;
            }
        }

        # Assign
        c = best_cn.crew;
        c.status = CrewStatus.TRAVELLING;
        c.task_fault_id = f.id;
        c.eta_min = best_tt;
        label_crew(c);

        f.crew_id = c.id;
        f.eta_min = best_tt;
        f.status = FaultStatus.CREW_ASSIGNED;
        label_fault(f);

        self.assigned.append(c.id);

        # Target coordinates
        target_node = _find_grid_node(f.device_id);
        target_x = target_node.x if target_node else c.x;
        target_y = target_node.y if target_node else c.y;

        DISPATCH_TRACKER[c.id] = {
            "fault_id": f.id,
            "device_id": f.device_id,
            "start_min": self.clock_min,
            "arrival_min": self.clock_min + float(best_tt),
            "start_x": c.x,
            "start_y": c.y,
            "target_x": target_x,
            "target_y": target_y
        };

        if elog {
            elog.events.append(Event(
                time_min=self.clock_min,
                kind="crew_dispatched",
                text=f"{c.name or c.id} dispatched to {f.id} on {f.device_id} (ETA {best_tt} mins)",
                fault_id=f.id
            ));
        }
    }
}
