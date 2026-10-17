"""Snapshot (WP-B4): walks the grid from SS1 over Feeds and collects views for get_grid.

Each node is visited once (TS1 has a Feeds edge from both feeders).
sim.grid_view adds depots, landmarks, crews and fault colours afterwards.
"""

impl Snapshot.collect {
    if here.id in self.seen {
        skip;
    }
    self.seen.append(here.id);
    v = GridNodeView(id=here.id, kind="node", x=here.x, y=here.y, label=here.id, energised=here.energised, has_power=here.energised);
    if isinstance(here, Substation) {
        v.kind = "substation";
        v.label = here.name or here.id;
    } elif isinstance(here, Section) {
        v.kind = "section";
        v.work_zone = here.work_zone;
    } elif isinstance(here, Switch) {
        v.kind = "switch";
        v.closed = here.closed;
        v.tie = here.kind == "tie";
        v.label = f"{here.id} ({here.kind})" if here.kind != "switch" else here.id;
    } elif isinstance(here, Transformer) {
        v.kind = "transformer";
        v.homes = here.homes;
        ups = parents(here);
        v.parent_id = ups[0].id if ups else "";
        for k in children(here) {
            if isinstance(k, Microgrid) and k.supplying {
                v.powered_by = k.id;
            }
        }
    } elif isinstance(here, Microgrid) {
        v.kind = "microgrid";
        v.label = here.name or here.id;
        v.parent_id = parents(here)[0].id if parents(here) else "";
        v.battery_min = here.battery_min;
        v.battery_max = here.battery_max;
        v.supplying = here.supplying;
        v.islanded = here.islanded;
        v.isolated = here.isolated;
        v.has_power = here.supplying;
        v.status = "restored" if here.supplying else "normal";
    } elif isinstance(here, Home) {
        v.kind = "home";
        v.label = here.consumer_no;
        v.parent_id = here.transformer_id;
        v.has_power = here.has_power;
        v.reported = here.reported;
    }
    self.nodes.append(v);
    kids = children(here);
    for child in kids {
        is_tie: bool = isinstance(child, Switch) and child.kind == "tie";
        closed: bool = child.closed if isinstance(child, Switch) else True;
        ekind: str = "backup" if isinstance(child, Microgrid) else ("tie" if is_tie else "feeds");
        self.edges.append(GridEdgeView(from_id=here.id, to_id=child.id, kind=ekind, closed=closed));
    }
    visit kids;
}
