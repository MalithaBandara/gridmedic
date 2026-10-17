"""Energiser (WP-C3, CLAUDE.md §8.3, PLAN.md §2, §5 WP-C3).

Bidirectional flood fill from SS1 through closed switches and healthy sections,
following Feeds edges in both directions so the tie TS1 works either way.
Sets Section.energised, Switch.energised, Transformer.energised, and
Home.has_power / Home.energised, respecting line_ok, closed switches, fuse_ok,
and service_ok[street].
"""

impl Energiser.spread {
    if isinstance(here, Substation) {
        self.live = [];
        seen: set[str] = set();
        q: list[GridNode] = [here];
        while q {
            curr = q.pop(0);
            if curr.id in seen {
                continue;
            }
            seen.add(curr.id);
            curr.energised = False;
            if isinstance(curr, Home) {
                (curr as Home).has_power = False;
            }
            q.extend(children(curr));
        }
    }

    if here.id in self.live {
        skip;
    }

    if isinstance(here, Substation) {
        here.energised = True;
        self.live.append(here.id);
        visit [n for n in children(here) if n.id not in self.live];
    } elif isinstance(here, Section) {
        sec = here as Section;
        if not sec.line_ok {
            sec.energised = False;
            skip;
        }
        sec.energised = True;
        self.live.append(sec.id);
        seen_ids: set[str] = set(self.live);
        nbrs: list[GridNode] = [];
        for n in children(sec) + parents(sec) {
            if n.id not in seen_ids {
                seen_ids.add(n.id);
                nbrs.append(n);
            }
        }
        visit nbrs;
    } elif isinstance(here, Switch) {
        sw = here as Switch;
        if not sw.closed {
            sw.energised = False;
            skip;
        }
        sw.energised = True;
        self.live.append(sw.id);
        seen_ids: set[str] = set(self.live);
        nbrs: list[GridNode] = [];
        for n in children(sw) + parents(sw) {
            if n.id not in seen_ids {
                seen_ids.add(n.id);
                nbrs.append(n);
            }
        }
        visit nbrs;
    } elif isinstance(here, Transformer) {
        tx = here as Transformer;
        if not tx.fuse_ok {
            tx.energised = False;
            skip;
        }
        tx.energised = True;
        self.live.append(tx.id);
        for h in children(tx) {
            if isinstance(h, Home) {
                hm = h as Home;
                ok = tx.service_ok.get(hm.street, True);
                hm.has_power = ok;
                hm.energised = ok;
                if ok {
                    self.live.append(hm.id);
                }
            }
        }
    }
}
