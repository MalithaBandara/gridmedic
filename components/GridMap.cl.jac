"""Live single-line grid diagram drawn from get_grid's GridView (CLAUDE.md §6.1 x/y).

Lines follow power state; devices take their fault colour (suspected orange,
faulted red, restored green); home dots pulse orange once they have reported.
Government Command Center Styling.
"""

sv import from ..gm_types { GridView, GridNodeView, GridEdgeView }

glob LIVE: str = "#10b981";
glob DEAD: str = "#334155";
glob SUSPECT: str = "#f59e0b";
glob FAULT: str = "#ef4444";
glob RESTORED: str = "#22c55e";
glob TIE: str = "#38bdf8";

def status_colour(status: str, fallback: str) -> str {
    if status == "faulted" {
        return FAULT;
    }
    if status == "suspected" {
        return SUSPECT;
    }
    if status == "restored" {
        return RESTORED;
    }
    return fallback;
}

def edge_colour(e: GridEdgeView, b: GridNodeView) -> str {
    if e.kind == "transmission" {
        return LIVE if b.energised else DEAD;
    }
    if e.kind == "backup" {
        return RESTORED if b.supplying else DEAD;
    }
    if e.kind == "tie" {
        return LIVE if e.closed else TIE;
    }
    if b.status == "faulted" and b.kind == "section" {
        return FAULT;
    }
    return LIVE if b.energised else DEAD;
}

def home_colour(h: GridNodeView) -> str {
    if h.reported {
        return SUSPECT;
    }
    return "#34d399" if h.has_power else "#1e293b";
}

def:pub GridMap(grid: GridView | None) -> JsxElement {
    if grid is None {
        return <div style={{"color": "#64748b", "padding": "2rem", "textAlign": "center"}}>{"Loading SCADA Grid Telemetry…"}</div>;
    }
    nodes: list[GridNodeView] = grid.nodes;
    all_edges: list[GridEdgeView] = grid.edges;
    pos: dict[str, GridNodeView] = {};
    for n in nodes {
        pos[n.id] = n;
    }
    lines: list[GridEdgeView] = [e for e in all_edges if e.from_id in pos and e.to_id in pos and pos[e.to_id].kind != "home"];
    homes: list[GridNodeView] = [n for n in nodes if n.kind == "home"];
    devices: list[GridNodeView] = [n for n in nodes if n.kind != "home" and n.kind != "crew"];
    crews: list[GridNodeView] = [n for n in nodes if n.kind == "crew"];

    return
        <svg width="100%" viewBox="30 40 820 540" style={{"display": "block", "maxHeight": "520px", "userSelect": "none"}}>
            {#* Feeder Zone Shading - Government Blueprint style *#}
            <rect x="40" y="55" width="800" height="150" rx="8" fill="rgba(2, 132, 199, 0.04)" stroke="rgba(56, 189, 248, 0.25)" strokeDasharray="3,3"/>
            <rect x="40" y="395" width="800" height="170" rx="8" fill="rgba(16, 185, 129, 0.04)" stroke="rgba(16, 185, 129, 0.25)" strokeDasharray="3,3"/>
            <text x="50" y="73" fill="#38bdf8" fontSize="9" fontWeight="700" letterSpacing="0.06em">{"FEEDER 01 · 11kV RADIAL (AREA NORTH · 310 CONSUMERS)"}</text>
            <text x="50" y="557" fill="#34d399" fontSize="9" fontWeight="700" letterSpacing="0.06em">{"FEEDER 02 · 11kV RADIAL (AREA SOUTH · 290 CONSUMERS)"}</text>

            {#* Primary Distribution Lines *#}
            {for e in lines {
                <line
                    key={e.from_id + ">" + e.to_id}
                    x1={pos[e.from_id].x}
                    y1={pos[e.from_id].y}
                    x2={pos[e.to_id].x}
                    y2={pos[e.to_id].y}
                    stroke={edge_colour(e, pos[e.to_id])}
                    strokeWidth={6 if e.kind == "transmission" else (2 if e.kind == "tie" or e.kind == "backup" or pos[e.to_id].kind == "transformer" else 4)}
                    strokeDasharray={"5,4" if (e.kind == "tie" and not e.closed) or e.kind == "backup" else "0"}
                />
            }}

            {#* 600 Consumer Metering Points *#}
            {for h in homes {
                <circle key={h.id} cx={h.x} cy={h.y} r="1.6" fill={home_colour(h)}>
                    {h.reported and <animate attributeName="opacity" values="1;0.35;1" dur="1.6s" repeatCount="indefinite"/>}
                </circle>
            }}

            {#* Electrical Equipment & Nodes *#}
            {for n in devices {
                if n.kind == "substation" {
                    <g key={n.id}>
                        <rect x={n.x - 38} y={n.y - 24} width="76" height="48" rx="6" fill="#0f172a" stroke="#0284c7" strokeWidth="2"/>
                        <text x={n.x} y={n.y - 2} fill="#38bdf8" fontSize="10" fontWeight="800" textAnchor="middle">{n.id}</text>
                        <text x={n.x} y={n.y + 12} fill="#94a3b8" fontSize="7" fontWeight="600" textAnchor="middle">{"MORATUWA GS"}</text>
                    </g>
                } elif n.kind == "section" {
                    <g key={n.id}>
                        <circle cx={n.x} cy={n.y} r="13" fill="#0b1120" stroke={status_colour(n.status, LIVE if n.energised else DEAD)} strokeWidth={3 if n.work_zone else 2}/>
                        <text x={n.x} y={n.y + 3} fill="#e2e8f0" fontSize="8" fontWeight="600" textAnchor="middle">{n.id}</text>
                    </g>
                } elif n.kind == "switch" {
                    <g key={n.id}>
                        <rect x={n.x - 14} y={n.y - 9} width="28" height="18" rx="3" fill={(TIE if n.tie else LIVE) if n.closed else "#0b1120"} stroke={TIE if n.tie else (FAULT if n.status == "faulted" else LIVE)} strokeWidth="1.5" strokeDasharray={"3,2" if n.tie else "0"}/>
                        <text x={n.x} y={n.y + 3} fill="#f8fafc" fontSize="7" fontWeight="700" textAnchor="middle">{n.id}</text>
                    </g>
                } elif n.kind == "transformer" {
                    <g key={n.id}>
                        <rect x={n.x - 11} y={n.y - 8} width="22" height="16" rx="2" fill="#0b1120" stroke={status_colour(n.status, LIVE if n.energised else DEAD)} strokeWidth="2"/>
                        <text x={n.x} y={n.y + 3} fill="#e2e8f0" fontSize="7" fontWeight="600" textAnchor="middle">{n.id}</text>
                    </g>
                } elif n.kind == "transmission" {
                    <g key={n.id}>
                        <line x1="34" y1={n.y} x2={n.x} y2={n.y} stroke={status_colour(n.status, LIVE if n.energised else DEAD)} strokeWidth="6"/>
                        <path d={f"M{n.x - 8} {n.y + 12} L{n.x} {n.y - 14} L{n.x + 8} {n.y + 12} M{n.x - 10} {n.y - 6} L{n.x + 10} {n.y - 6}"} fill="none" stroke={status_colour(n.status, "#94a3b8")} strokeWidth="1.5"/>
                        <text x={n.x} y={n.y - 20} fill={status_colour(n.status, "#cbd5e1")} fontSize="8" fontWeight="bold" textAnchor="middle">{n.label}</text>
                        {(n.status != "normal") and <text x={n.x} y={n.y + 26} fill={status_colour(n.status, FAULT)} fontSize="9" fontWeight="bold" textAnchor="middle">{"⚠ supply lost"}</text>}
                    </g>
                } elif n.kind == "microgrid" {
                    <g key={n.id}>
                        <rect x={n.x - 24} y={n.y - 12} width="48" height="24" rx="5" fill={"#064e3b" if n.supplying else "#0f172a"} stroke={RESTORED if n.supplying else ("#a3e635" if n.isolated else DEAD)} strokeWidth="2"/>
                        <text x={n.x} y={n.y - 1} fill="#f8fafc" fontSize="7" fontWeight="bold" textAnchor="middle">{"⚡ " + n.id}</text>
                        <rect x={n.x - 18} y={n.y + 4} width="36" height="3" rx="1" fill="#1e293b"/>
                        <rect x={n.x - 18} y={n.y + 4} width={36 * n.battery_min / max(1, n.battery_max)} height="3" rx="1" fill={RESTORED if n.supplying else "#64748b"}/>
                    </g>
                } elif n.kind == "depot" {
                    <g key={n.id}>
                        <rect x={n.x - 30} y={n.y - 12} width="60" height="24" rx="4" fill="#131d31" stroke="#475569"/>
                        <text x={n.x} y={n.y + 3} fill="#cbd5e1" fontSize="7" fontWeight="600" textAnchor="middle">{n.label}</text>
                    </g>
                } elif n.kind == "landmark" and n.id.startswith("POLE") {
                    if n.status != "normal" {
                        <text key={n.id} x={n.x} y={n.y - 18} fill={FAULT} fontSize="11" fontWeight="bold" textAnchor="middle">{"⚠ " + n.label}</text>
                    }
                } elif n.kind == "landmark" {
                    <text key={n.id} x={n.x} y={n.y} fill={(FAULT if not n.has_power else (RESTORED if n.status != "normal" else "#64748b"))} fontSize="7" fontWeight="600" textAnchor="middle">{"✦ " + n.label}</text>
                }
            }}

            {#* Field Crew Units *#}
            {for (i, c) in enumerate(crews) {
                <g key={c.id}>
                    <circle cx={c.x - 9 + (i % 2) * 18} cy={c.y + 22} r="8" fill="#7c3aed" stroke="#ddd6fe" strokeWidth="1.5"/>
                    <text x={c.x - 9 + (i % 2) * 18} y={c.y + 25} fill="#fff" fontSize="8" fontWeight="bold" textAnchor="middle">{c.label[-1:]}</text>
                </g>
            }}
        </svg>;
}
