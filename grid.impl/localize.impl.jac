"""Localiser + node tallies (WP-B2, CLAUDE.md §8.2).

The walker only climbs. Counting happens on the nodes: each Home marks itself
reported and each Transformer/Section tallies the walker that reaches it.
On every node the walker's ability runs first, so climb still sees the
Home's old `reported` flag: a home that was already counted stops the climb
there, which keeps the tallies at DISTINCT reporting homes. The same rule
covers a home that appears twice in one batch.

One walker climbs from every start, so it reaches a shared Transformer once
per reporting home: that is the tally. `path` only records where it went.
"""

impl Localiser.begin {
    visit self.starts;
}

impl Localiser.climb {
    self.path.append(here.id);
    counted = isinstance(here, Home) and (here as Home).reported;
    # Never climb through the normally-open tie: F1 and F2 stay separate trees.
    tie = isinstance(here, Switch)
        and ((here as Switch).normally_open or (here as Switch).kind == "tie");
    if not counted and not tie {
        visit parents(here);
    }
}

impl Home.mark {
    self.reported = True;
}

impl Transformer.tally {
    self.reports += 1;
}

impl Section.tally {
    self.reports += 1;
}
