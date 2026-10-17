"""Verifier (WP-B7, CLAUDE.md §8.9): did the repair really restore everyone?

After a fault is restored, homes below its device that keep complaining within
the window point at a hidden second fault. Complaints are tallied per
transformer (distinct homes); a transformer with `min_reports` or more, and no
active fault of its own, gets a new TX_FUSE marked found_by="verifier".
Reads complaints and tallies only, never physical truth (fuse_ok etc.).
"""

# Every node under `start`, not climbing through a tie switch into the other feeder.
def _below(start: GridNode) -> dict[str, GridNode] {
    out: dict[str, GridNode] = {};
    queue: list[GridNode] = [start];
    while queue {
        n = queue.pop(0);
        if n.id in out {
            continue;
        }
        out[n.id] = n;
        if isinstance(n, Switch) and n.kind == "tie" {
            continue;
        }
        queue.extend(children(n));
    }
    return out;
}

def _is_finished(f: Fault) -> bool {
    return f.status == FaultStatus.RESTORED or f.status == FaultStatus.CLOSED;
}

impl Verifier.check {
    subs = [here -->[?:Substation]];
    states = [here -->[?:SimState]];
    if len(subs) == 0 or len(states) == 0 or len(self.restored) == 0 {
        return;
    }
    by_id = _below(subs[0]);
    fnodes = [here -->[?:FaultNode]];
    active: set[str] = set([fn.fault.device_id for fn in fnodes if not _is_finished(fn.fault)]);
    for fid in list(self.restored.keys()) {
        t0: float = self.restored[fid];
        repaired = [fn.fault for fn in fnodes if fn.fault.id == fid];
        if len(repaired) == 0 or repaired[0].device_id not in by_id {
            continue;
        }
        rf = repaired[0];
        homes: dict[str, Home] = {};
        for (nid, n) in _below(by_id[rf.device_id]).items() {
            if isinstance(n, Home) {
                homes[nid] = n;
            }
        }
        # tx id -> {home id -> complaint}: distinct homes, in the window, not duplicates
        per_tx: dict[str, dict[str, Complaint]] = {};
        for c in self.complaints {
            if c.is_duplicate or c.home_id not in homes {
                continue;
            }
            if c.time_min < t0 or c.time_min > t0 + self.window_min {
                continue;
            }
            tid = homes[c.home_id].transformer_id;
            if tid not in per_tx {
                per_tx[tid] = {};
            }
            per_tx[tid][c.home_id] = c;
        }
        for (tid, reporters) in per_tx.items() {
            if len(reporters) < self.min_reports or tid in active or tid not in by_id {
                continue;
            }
            tx = by_id[tid];
            if not isinstance(tx, Transformer) {
                continue;
            }
            st = states[0];
            no = st.next_fault_no;    # same ids as agents_group._next_fault_id
            st.next_fault_no = no + 1;
            cs = list(reporters.values());
            f = label_fault(Fault(
                id=f"FLT-{no:03d}",
                kind=FaultKind.TX_FUSE,
                device_id=tid,
                homes_affected=tx.homes,
                critical_loads=list(tx.critical),
                confidence=0.7,
                status=FaultStatus.SUSPECTED,
                evidence=[
                    f"{len(cs)} homes on {tid} kept reporting after the {rf.device_id} repair",
                    f"complaints continued after {rf.device_id} repair"
                ],
                complaint_ids=[c.id for c in cs],
                first_report_min=min([c.time_min for c in cs]),
                found_by="verifier"
            ));
            root ++> FaultNode(fault=f);
            active.add(tid);
            self.new_fault_ids.append(f.id);
        }
    }
}
