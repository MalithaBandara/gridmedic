"""Bodies for agents_parse.jac."""

impl bd_number(text: str) -> str {
    m = BD_RE.match(text);
    return str(m.group(1)) if m else "";
}

impl _cache_key(text: str) -> str {
    return " ".join(text.strip().split());
}

impl _cache -> ParseCache {
    found = [root -->[?:ParseCache]];
    if found {
        return found[0];
    }
    return (root ++> ParseCache())[0] as ParseCache;
}

impl _fallback(index: int) -> ParsedText {
    return ParsedText(index=index, lang=Lang.MIXED, hazard=Hazard.NONE, landmark="");
}

impl _apply(c: Complaint, p: ParsedText) {
    q = fix_parsed(p);
    c.lang = q.lang;
    c.hazard = q.hazard;
    if p.landmark and not c.landmark {
        c.landmark = p.landmark;
    }
}

def _inc_llm_calls {
    m = sys.modules.get("agents_parse");
    if m { m.LLM_CALLS += 1; }
}

def _inc_cache_hits {
    m = sys.modules.get("agents_parse");
    if m { m.CACHE_HITS += 1; }
}

def _inc_bd_skips {
    m = sys.modules.get("agents_parse");
    if m { m.BD_SKIPS += 1; }
}

# Rate-limit check by class name: byllm is not importable on every Jac line
# (Jac Hammer bundles it), so we don't import byllm.lib.RateLimitError.
impl _is_rate_limit(e: Exception) -> bool {
    return "RateLimit" in type(e).__name__;
}

# One LLM batch call. Retries once on a rate limit; after that (or any other
# error) returns [] and the caller falls back. The storm must never crash.
impl _call_batch(texts: list[str]) -> list[LlmParsed] {
    for attempt in range(2) {
        try {
            _inc_llm_calls();
            return parse_texts(texts);
        } except Exception as e {
            if _is_rate_limit(e) {
                if attempt == 0 {
                    sleep(RETRY_WAIT_S);
                }
            } else {
                print(f"[agents_parse] batch parse failed: {str(e)}");
                return [];
            }
        }
    }
    return [];
}

impl _call_single(raw: str) -> LlmParsed | None {
    for attempt in range(2) {
        try {
            _inc_llm_calls();
            return parse_single(raw);
        } except Exception as e {
            if _is_rate_limit(e) {
                if attempt == 0 {
                    sleep(RETRY_WAIT_S);
                }
            } else {
                print(f"[agents_parse] single parse failed: {str(e)}");
                return None;
            }
        }
    }
    return None;
}

# A helper per launch: `flow` inside a comprehension binds late (CLAUDE.md §1a).
impl _launch(texts: list[str]) -> Future {
    return (flow _call_batch(texts)) as Future;
}

# Parses distinct, uncached texts; returns text -> ParsedText. Successful
# results go into the cache; failures get a non-cached fallback.
impl _parse_free_texts(texts: list[str]) -> dict[str, ParsedText] {
    out: dict[str, ParsedText] = {};
    chunks: list[list[str]] = [texts[i:i + BATCH_SIZE] for i in range(0, len(texts), BATCH_SIZE)];
    cache = _cache();
    entries: dict[str, ParsedText] = dict(cache.entries);
    for w in range(0, len(chunks), MAX_PARALLEL) {
        wave: list[list[str]] = chunks[w:w + MAX_PARALLEL];
        futures: list[Future] = [_launch(ch) for ch in wave];
        results: list[list[LlmParsed]] = [(wait f) as list[LlmParsed] for f in futures];
        for (ch, items) in zip(wave, results) {
            by_index: dict[int, LlmParsed] = {};
            for it in items {
                if 0 <= it.index < len(ch) {
                    by_index[it.index] = it;
                }
            }
            for (i, text) in enumerate(ch) {
                if i in by_index {
                    pt = to_parsed_text(by_index[i]);
                    out[text] = pt;
                    entries[text] = pt;
                } else {
                    out[text] = _fallback(i);
                }
            }
        }
    }
    cache.entries = entries;    # reassign so the change persists
    return out;
}

impl parse_batch(complaints: list[Complaint]) -> list[Complaint] {
    cache = _cache();
    known: dict[str, ParsedText] = dict(cache.entries);
    pending: dict[str, list[Complaint]] = {};
    for c in complaints {
        num = bd_number(c.text);
        if num {
            _inc_bd_skips();
            c.consumer_no = num;
            c.lang = Lang.EN;
            c.hazard = Hazard.NONE;
            continue;
        }
        if is_mock() {
            # Offline stand-in: no Gemini, and nothing is read from or written to ParseCache.
            _apply(c, mock_parse(c.text));
            continue;
        }
        key = _cache_key(c.text);
        if key in known {
            _inc_cache_hits();
            _apply(c, known[key]);
        } else {
            if key not in pending {
                pending[key] = [];
            }
            pending[key].append(c);
        }
    }
    if pending {
        parsed = _parse_free_texts(list(pending.keys()));
        failed: int = 0;
        for (key, group) in pending.items() {
            p = parsed[key] if key in parsed else _fallback(0);
            if p.lang == Lang.MIXED and p.hazard == Hazard.NONE and key not in _cache().entries {
                failed += len(group);
            }
            for c in group {
                _apply(c, p);
            }
        }
        if failed > 0 {
            t: float = complaints[0].time_min if complaints else 0.0;
            _log("parse_failed", f"{failed} complaint(s) could not be parsed by the LLM; treated as no-hazard", t);
        }
    }
    homes = _homes_by_consumer();
    for c in complaints {
        _locate(c, homes);
    }
    return complaints;
}

impl parse_one(c: Complaint) -> Complaint {
    num = bd_number(c.text);
    if num {
        _inc_bd_skips();
        c.consumer_no = num;
    } elif is_mock() {
        _apply(c, mock_parse(c.text));
    } else {
        key = _cache_key(c.text);
        cache = _cache();
        if key in cache.entries {
            _inc_cache_hits();
            _apply(c, cache.entries[key]);
        } else {
            p = _call_single(c.text);
            if p is None {
                _apply(c, _fallback(0));
                _log("parse_failed", f"{c.id} could not be parsed by the LLM; treated as no-hazard", c.time_min);
            } else {
                pt = to_parsed_text(p);
                pt.index = 0;
                entries: dict[str, ParsedText] = dict(cache.entries);
                entries[key] = pt;
                cache.entries = entries;
                _apply(c, pt);
            }
        }
    }
    _locate(c, _homes_by_consumer());
    return c;
}

def _complaint_time_key(x: Complaint) -> float {
    return x.time_min;
}

impl flag_duplicates(new_items: list[Complaint], earlier: list[Complaint]) -> list[Complaint] {
    last_counted: dict[str, float] = {};
    for e in earlier {
        if e.consumer_no and not e.is_duplicate {
            last_counted[e.consumer_no] = e.time_min;
        }
    }
    for c in sorted(new_items, key=_complaint_time_key) {
        if not c.consumer_no {
            continue;
        }
        if c.consumer_no in last_counted and c.time_min - last_counted[c.consumer_no] <= DUPLICATE_WINDOW_MIN {
            c.is_duplicate = True;
        } else {
            last_counted[c.consumer_no] = c.time_min;
        }
    }
    return new_items;
}

# Every grid node reachable from the substations over Feeds (either direction
# of the tie switch is covered by the seen set).
impl _grid_nodes -> list[GridNode] {
    seen: set[str] = set();
    out: list[GridNode] = [];
    queue: list[GridNode] = [s for s in [root -->[?:Substation]]];
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

impl _homes_by_consumer -> dict[str, Home] {
    homes: dict[str, Home] = {};
    for n in _grid_nodes() {
        if isinstance(n, Home) {
            homes[n.consumer_no] = n;
        }
    }
    return homes;
}

impl _landmarks -> list[Landmark] {
    found: dict[str, Landmark] = {};
    for lm in [root -->[?:Landmark]] {
        found[lm.id] = lm;
    }
    for n in _grid_nodes() {
        if isinstance(n, Landmark) {
            found[n.id] = n;
        }
        if isinstance(n, Section) {
            for lm in [x for x in [n <--] if isinstance(x, Landmark)] {
                found[lm.id] = lm;
            }
        }
    }
    return list(found.values());
}

impl landmark_section(text: str) -> str {
    t = " " + " ".join(re.findall(r"[a-z0-9]+", text.lower())) + " ";
    if t.strip() == "" {
        return "";
    }
    for lm in _landmarks() {
        name = " ".join(re.findall(r"[a-z0-9]+", lm.name.lower()));
        if name and (" " + name + " ") in t {
            return lm.section_id;
        }
        # "pole 23" also matches "pole no 23", "pole #23" and "kanuwa 23"
        digits = re.findall(r"\d+", name);
        if digits and ("pole" in name) {
            num: str = str(digits[0]);
            pattern: str = r"(pole|kanuwa|කණුව)\D{0,6}" + num + r"(?!\d)";
            if re.search(pattern, text.lower()) {
                return lm.section_id;
            }
        }
    }
    return "";
}

impl _locate(c: Complaint, homes: dict[str, Home]) {
    if not c.consumer_no {
        m = NUM_RE.search(c.text);
        if m {
            c.consumer_no = str(m.group(1));
        }
    }
    if c.consumer_no and c.consumer_no in homes {
        c.home_id = homes[c.consumer_no].id;
    }
    if not c.landmark {
        # Landmark words in the raw text, e.g. a BD SMS never has one, but
        # "near pole 23" free text without an LLM landmark still maps.
        if landmark_section(c.text) {
            m2 = re.search(r"(pole|kanuwa)\D{0,6}\d+", c.text.lower());
            c.landmark = str(m2.group(0)) if m2 else "";
        }
    }
}

impl _log(kind: str, text: str, time_min: float) {
    logs = [root -->[?:EventLog]];
    log = logs[0] if logs else (root ++> EventLog())[0] as EventLog;
    events: list[Event] = list(log.events);
    events.append(Event(time_min=time_min, kind=kind, text=text));
    log.events = events;
}
