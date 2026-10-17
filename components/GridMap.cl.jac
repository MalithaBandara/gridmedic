"""Live single-line grid diagram drawn from get_grid's GridView (CLAUDE.md §6.1 x/y).

Minimalist single-line schematic: calm, clean, high-contrast, uncluttered.
"""

sv import from ..gm_types { GridView, GridNodeView, GridEdgeView }

glob LIVE: str = "#10b981";
glob DEAD: str = "#334155";
glob SUSPECT: str = "#f59e0b";
glob FAULT: str = "#ef4444";
glob RESTORED: str = "#10b981";
glob TIE: str = "#64748b";

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
        return LIVE if e.closed else "#475569";
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
    return "#10b981" if h.has_power else "#1e293b";
}

def:pub GridMap(grid: GridView | None) -> JsxElement {
    if grid is None {
        return <div style={{"color": "#64748b", "padding": "2rem", "textAlign": "center"}}>{"Loading schematic…"}</div>;
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
        <svg width="100%" viewBox="30 40 820 540" style={{"display": "block", "maxHeight": "500px", "userSelect": "none"}}>
            {#* Subtle Minimal Feeder Zone Labels (Quiet, no harsh colored borders) *#}
            <line x1="40" y1="55" x2="840" y2="55" stroke="#1e293b" strokeWidth="1" strokeDasharray="4,4"/>
            <text x="50" y="70" fill="#64748b" fontSize="9" fontWeight="600" letterSpacing="0.05em">{"FEEDER 1 (AREA NORTH · 310 HOMES)"}</text>

            <line x1="40" y1="395" x2="840" y2="395" stroke="#1e293b" strokeWidth="1" strokeDasharray="4,4"/>
            <text x="50" y="555" fill="#64748b" fontSize="9" fontWeight="600" letterSpacing="0.05em">{"FEEDER 2 (AREA SOUTH · 290 HOMES)"}</text>

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

            {#* 600 Consumer Metering Points (Minimal dots) *#}
            {for h in homes {
                <circle key={h.id} cx={h.x} cy={h.y} r="1.5" fill={home_colour(h)}>
                    {h.reported and <animate attributeName="opacity" values="1;0.4;1" dur="1.5s" repeatCount="indefinite"/>}
                </circle>
            }}

            {#* Electrical Equipment & Nodes *#}
            {for n in devices {
                if n.kind == "substation" {
                    <g key={n.id}>
                        <rect x={n.x - 34} y={n.y - 20} width="68" height="40" rx="4" fill="#0f172a" stroke="#475569" strokeWidth="1.5"/>
                        <text x={n.x} y={n.y + 1} fill="#f8fafc" fontSize="11" fontWeight="700" textAnchor="middle">{n.id}</text>
                        <text x={n.x} y={n.y + 12} fill="#64748b" fontSize="6.5" textAnchor="middle">{"MORATUWA"}</text>
                    </g>
                } elif n.kind == "section" {
                    <g key={n.id}>
                        <circle cx={n.x} cy={n.y} r="12" fill="#090d16" stroke={status_colour(n.status, LIVE if n.energised else DEAD)} strokeWidth={2.5 if n.work_zone else 1.5}/>
                        <text x={n.x} y={n.y + 3} fill="#e2e8f0" fontSize="7.5" fontWeight="600" textAnchor="middle">{n.id}</text>
                    </g>
                } elif n.kind == "switch" {
                    <g key={n.id}>
                        <rect x={n.x - 13} y={n.y - 8} width="26" height="16" rx="2" fill={(LIVE if n.closed else "#090d16")} stroke={LIVE if n.closed else "#475569"} strokeWidth="1.2" strokeDasharray={"3,2" if n.tie else "0"}/>
                        <text x={n.x} y={n.y + 3} fill={("#ffffff" if n.closed else "#94a3b8")} fontSize="7" fontWeight="600" textAnchor="middle">{n.id}</text>
                    </g>
                } elif n.kind == "transformer" {
                    <g key={n.id}>
                        <rect x={n.x - 10} y={n.y - 7} width="20" height="14" rx="2" fill="#090d16" stroke={status_colour(n.status, LIVE if n.energised else DEAD)} strokeWidth="1.5"/>
                        <text x={n.x} y={n.y + 3} fill="#cbd5e1" fontSize="6.5" textAnchor="middle">{n.id}</text>
                    </g>
                } elif n.kind == "transmission" {
                    <g key={n.id}>
                        <line x1="34" y1={n.y} x2={n.x} y2={n.y} stroke={status_colour(n.status, LIVE if n.energised else DEAD)} strokeWidth="6"/>
                        <path d={f"M{n.x - 8} {n.y + 12} L{n.x} {n.y - 14} L{n.x + 8} {n.y + 12} M{n.x - 10} {n.y - 6} L{n.x + 10} {n.y - 6}"} fill="none" stroke={status_colour(n.status, "#94a3b8")} strokeWidth="1.5"/>
                        <text x={n.x} y={n.y - 20} fill={status_colour(n.status, "#cbd5e1")} fontSize="8" fontWeight="bold" textAnchor="middle">{n.label}</text>
                        {(n.status != "normal") and <text x={n.x} y={n.y + 26} fill={status_colour(n.status, FAULT)} fontSize="9" fontWeight="bold" textAnchor="middle">{"SUPPLY LOST"}</text>}
                    </g>
                } elif n.kind == "microgrid" {
                    <g key={n.id}>
                        <rect x={n.x - 22} y={n.y - 10} width="44" height="20" rx="3" fill={"#064e3b" if n.supplying else "#0f172a"} stroke={RESTORED if n.supplying else "#475569"} strokeWidth="1.2"/>
                        <text x={n.x} y={n.y - 1} fill="#f8fafc" fontSize="6.5" fontWeight="600" textAnchor="middle">{n.id}</text>
                        <rect x={n.x - 16} y={n.y + 3} width="32" height="2.5" rx="1" fill="#1e293b"/>
                        <rect x={n.x - 16} y={n.y + 3} width={32 * n.battery_min / max(1, n.battery_max)} height="2.5" rx="1" fill={RESTORED if n.supplying else "#64748b"}/>
                    </g>
                } elif n.kind == "depot" {
                    <g key={n.id}>
                        <rect x={n.x - 26} y={n.y - 10} width="52" height="20" rx="3" fill="#0f172a" stroke="#334155" strokeWidth="1"/>
                        <text x={n.x} y={n.y + 3} fill="#94a3b8" fontSize="6.5" textAnchor="middle">{n.label}</text>
                    </g>
                } elif n.kind == "landmark" and n.id.startswith("POLE") {
                    if n.status != "normal" {
                        <text key={n.id} x={n.x} y={n.y - 16} fill={FAULT} fontSize="9" fontWeight="700" textAnchor="middle">{n.label + " [FAULT]"}</text>
                    }
                } elif n.kind == "landmark" {
                    <text key={n.id} x={n.x} y={n.y} fill={(FAULT if not n.has_power else "#64748b")} fontSize="6.5" textAnchor="middle">{n.label}</text>
                }
            }}

            {#* Field Crew Units *#}
            {for (i, c) in enumerate(crews) {
                <g key={c.id}>
                    <circle cx={c.x - 9 + (i % 2) * 18} cy={c.y + 20} r="7" fill="#1e293b" stroke="#38bdf8" strokeWidth="1.5"/>
                    <text x={c.x - 9 + (i % 2) * 18} y={c.y + 23} fill="#38bdf8" fontSize="7" fontWeight="700" textAnchor="middle">{c.label[-1:]}</text>
                </g>
            }}
        </svg>;
}
