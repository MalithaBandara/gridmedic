"""Which language model the simulation uses.

"mock": deterministic offline stand-ins (rule-based parsers, evidence summary). No Gemini
        request is ever made, and nothing is written to the persisted ParseCache.
"real": the by llm() functions (Gemini). Uses API quota.

The mode lives in this module only (not in the graph), so a server restart goes back to
the default. start_storm sets it for the run; tests never touch it, so MockLLM-based
tests keep exercising the real by llm() plumbing.
"""

import sys;

glob _MODE: str = "real";

def current_mode -> str {
    return _MODE;
}

def is_mock -> bool {
    return _MODE == "mock";
}

"""Anything other than "mock" means "real"."""
def set_mode(mode: str) -> str {
    m = sys.modules.get("llm_switch", sys.modules.get(__name__));
    val = "mock" if mode == "mock" else "real";
    if m {
        m._MODE = val;
    }
    return val;
}
