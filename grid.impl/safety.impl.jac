"""SafetyCheck step + Switch guard (WP-C7). Placeholder bodies from WP-B0.

The walker's inline `gate` (grid.jac) disengages once blocked_by is set.
Switch.guard sets `visitor.blocked_by = self.id` instead of disengaging.
"""

impl SafetyCheck.step {}

impl Switch.guard {}
