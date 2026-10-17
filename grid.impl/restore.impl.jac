"""Restorer (WP-C7): microgrid start plans.

For every microgrid whose transformer is dark, offer the operator two plans:
  1. start it as it stands: BLOCKED, because with the HV isolator closed it
     would back-feed the dead network around the transformer (a faulted line,
     or a section where a crew is working);
  2. open the isolator first, then start it: SAFE if the battery lasts and the
     load fits.
Tie-switch plans (TS1) are added to this walker's output by the rest of WP-C7.
Applied actions are kept; the rest are rebuilt on every call.
"""

def _all_nodes(start: GridNode) -> list[GridNode] {
    seen: set[str] = set();
    out: list[GridNode] = [];
    queue: list[GridNode] = [start];
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

"""Why starting `mg` with its isolator closed is unsafe: the dead sections it would
re-energise, flagged if a crew works on one or a fault is believed to be on one."""
def _backfeed_reason(mg: Microgrid, t: Transformer, nodes: list[GridNode]) -> str {
    dead: dict[str, Section] = {};
    queue: list[GridNode] = [s for s in parents(t) if isinstance(s, Section)];
    while queue {
        n = queue.pop(0);
        if n.id in dead or n.energised {
            continue;
        }
        if isinstance(n, Section) {
            dead[n.id] = n;
        }
        if isinstance(n, Section) or isinstance(n, Switch) {
            if isinstance(n, Switch) and not n.closed {
                continue;
            }
            queue.extend(children(n) + parents(n));
        }
    }
    faulted: set[str] = set([fn.fault.device_id for fn in [root -->[?:FaultNode]]]);
    crew_on: list[str] = [sid for sid in dead.keys() if dead[sid].work_zone];
    fault_on: list[str] = [sid for sid in dead.keys() if sid in faulted];
    names = ", ".join(sorted(dead.keys()));
    why: str = f"Starting {mg.id} with {t.id}'s HV isolator closed would back-feed {names} through the transformer";
    crew_names = ", ".join(crew_on);
    fault_names = ", ".join(fault_on);
    if crew_on {
        why += f" while a crew is working on {crew_names}";
    } elif fault_on {
        why += f" and re-energise the faulted {fault_names}";
    }
    return why + ". Isolate the transformer first.";
}

impl Restorer.plan {
    ss = [s for s in [root -->[?:Substation]]];
    if ss {
        nodes = _all_nodes(ss[0]);
        stores = [root -->[?:ActionStore]];
        if stores {
            kept: list[Action] = [a for a in stores[0].actions if a.applied];
            planned: list[Action] = [];
            for mg in [n for n in nodes if isinstance(n, Microgrid)] {
                for t in parents(mg) {
                    if not isinstance(t, Transformer) or t.energised or mg.islanded or mg.battery_min <= 0 {
                        continue;
                    }
                    if not mg.critical_only and t.homes > mg.capacity_homes {
                        continue;    # load does not fit: nothing to offer
                    }
                    restored: int = 0 if mg.critical_only else t.homes;
                    load: str = t.critical[0].lower() if t.critical else "critical load";
                    source: str = mg.kind.lower().replace("_", " ");
                    what: str = f"{mg.name} powers the {load} on {t.id}" if mg.critical_only else f"{mg.name} powers {t.homes} homes on {t.id}";
                    fits: str = f"{what} for about {mg.battery_min} min on its {source}.";
                    if mg.isolated {
                        planned.append(Action(
                            id=f"ACT-{mg.id}-START", kind="microgrid",
                            steps=[SwitchStep(switch_id=mg.id, action="close")],
                            homes_restored=restored, safe=True, reason=fits
                        ));
                    } else {
                        planned.append(Action(
                            id=f"ACT-{mg.id}-NOISO", kind="microgrid",
                            steps=[SwitchStep(switch_id=mg.id, action="close")],
                            homes_restored=restored, safe=False,
                            reason=_backfeed_reason(mg, t, nodes)
                        ));
                        planned.append(Action(
                            id=f"ACT-{mg.id}-START", kind="microgrid",
                            steps=[SwitchStep(switch_id=mg.id + "-ISO", action="open"), SwitchStep(switch_id=mg.id, action="close")],
                            homes_restored=restored, safe=True,
                            reason=f"Open {t.id}'s HV isolator, then start {mg.id}. {fits}"
                        ));
                    }
                }
            }
            stores[0].actions = kept + [a for a in planned if a.id not in [k.id for k in kept]];
        }
    }
}
