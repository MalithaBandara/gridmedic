"""Restorer (WP-C7, CLAUDE.md §8.7, PLAN.md §5 WP-C7).

Builds tie-switch restoration actions:
- ACT-1: Close TS1 alone (unsafe: backfeeds into faulted/work-zone section F1-B).
- ACT-2: Open SW2 to isolate F1-B, then close TS1 (safe: restores T5's 70 homes via Feeder 2).
Runs SafetyCheck on each plan to evaluate safe and reason fields before storing in ActionStore.
"""

impl Restorer.plan {
    subs = [root -->[?:Substation]];
    if not subs {
        return;
    }
    ss = subs[0];

    # ACT-1: Close TS1 directly
    act1 = Action(
        id="ACT-1",
        kind="tie_restoration",
        steps=[SwitchStep(switch_id="TS1", action="close")],
        homes_restored=70,
        safe=False,
        reason=""
    );
    sc1 = SafetyCheck(steps=list(act1.steps));
    ss spawn sc1;
    act1.safe = sc1.safe;
    act1.reason = sc1.reason;

    # ACT-2: Open SW2 then close TS1
    act2 = Action(
        id="ACT-2",
        kind="tie_restoration",
        steps=[
            SwitchStep(switch_id="SW2", action="open"),
            SwitchStep(switch_id="TS1", action="close")
        ],
        homes_restored=70,
        safe=True,
        reason=""
    );
    sc2 = SafetyCheck(steps=list(act2.steps));
    ss spawn sc2;
    act2.safe = sc2.safe;
    act2.reason = sc2.reason;

    self.actions = [act1, act2];
    stores = [root -->[?:ActionStore]];
    if stores {
        stores[0].actions = [act1, act2];
    }
}
