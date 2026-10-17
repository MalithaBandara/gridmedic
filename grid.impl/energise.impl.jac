"""Energiser (WP-C3): who has power right now.

Spawned at SS1. Floods outward over Feeds in both directions (so the tie TS1
works either way) through closed switches, healthy sections and transformers
with a good fuse, then sets energised / has_power from the physical truth
(line_ok, fuse_ok, service_ok, locked_out). It may read that truth; the
discovery agents may not.

Microgrids add a second kind of source: an islanded microgrid with battery
left supplies the transformer it hangs off when the grid does not. A
critical_only set (the hospital) lights its landmark but not the homes. One
that runs without its isolator open also back-feeds the section above it.
"""

def _walk(start: GridNode) -> list[GridNode] {
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

def _can_enter(m: GridNode) -> bool {
    if isinstance(m, Switch) {
        return m.closed and not m.locked_out;
    }
    if isinstance(m, Section) {
        return m.line_ok;
    }
    if isinstance(m, Transformer) {
        return m.fuse_ok;
    }
    # Homes are lit through their transformer; microgrids and landmarks are not in the flood.
    return isinstance(m, Substation);
}

impl Energiser.spread {
    if isinstance(here, Substation) {
        nodes = _walk(here);
        live: set[str] = set([here.id]);
        queue: list[GridNode] = [here];
        while queue {
            n = queue.pop(0);
            for m in children(n) + parents(n) {
                if m.id not in live and _can_enter(m) {
                    live.add(m.id);
                    queue.append(m);
                }
            }
        }
        for n in nodes {
            if not isinstance(n, Home) and not isinstance(n, Microgrid) {
                n.energised = n.id in live;
            }
        }
        self.live = list(live);

        # Microgrids: supply a transformer the grid does not reach.
        service: dict[str, dict[str, bool]] = {};
        for n in nodes {
            if isinstance(n, Transformer) {
                service[n.id] = n.service_ok;
            }
        }
        fed: set[str] = set();
        lit: set[str] = set();
        for n in nodes {
            if isinstance(n, Microgrid) {
                n.supplying = False;
                if n.islanded and n.battery_min > 0 {
                    for t in parents(n) {
                        if isinstance(t, Transformer) and t.id not in live {
                            if n.critical_only {
                                n.supplying = True;
                                lit.add(n.landmark_id);
                            } elif t.homes <= n.capacity_homes {
                                n.supplying = True;
                                fed.add(t.id);
                                t.energised = True;
                            }
                            if n.supplying and not n.isolated {
                                for s in parents(t) {
                                    s.energised = True;    # back-fed through the HV side
                                }
                            }
                        }
                    }
                }
            }
        }

        for n in nodes {
            if isinstance(n, Home) {
                street_ok: bool = service.get(n.transformer_id, {}).get(n.street, True);
                n.has_power = (n.transformer_id in live or n.transformer_id in fed) and street_ok;
                n.energised = n.has_power;
            }
        }
        # Landmarks hang off their Section with a Located edge: lit when the
        # section is, or when a microgrid carries them.
        for n in nodes {
            if isinstance(n, Section) {
                for x in [n <--] {
                    if isinstance(x, Landmark) {
                        x.energised = n.id in live or x.id in lit;
                    }
                }
            }
        }
    }
}
