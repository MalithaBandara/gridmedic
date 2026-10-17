# Live Gemini smoke test for the F4 twist: ONE real parse_crew_report() call.
# Makes 1 real API call (byllm may retry malformed output). Run from the repo root:
#   jac run scripts/smoke_feedback.jac
# Needs GEMINI_API_KEY and JAC_OPT_LEVEL=0 in the environment.

import from gm_types { Fault, FaultKind, FaultStatus }
import from agents_feedback { parse_crew_report }

with entry:__main__ {
    fault = Fault(
        id="FLT-004", kind=FaultKind.TX_FUSE, device_id="T9", homes_affected=75,
        confidence=0.4, status=FaultStatus.CREW_ASSIGNED
    );
    text = "T9 transformer is fine, fuses OK. Other streets have power. Overhead service line down on Lake Road.";
    f = parse_crew_report(text, fault);
    print(f"fault_id={f.fault_id} device_ok={f.device_ok} new_kind={f.new_kind.name}");
    print(f"new_device_id='{f.new_device_id}' street='{f.street}' restored={f.restored} eta={f.repair_eta_min}");
    print(f"note: {f.note}");
    good: bool = f.device_ok and f.new_kind == FaultKind.SERVICE_WIRE and f.street == "Lake Road" and not f.restored;
    print("PASS: SERVICE_WIRE on Lake Road, T9 fine" if good else "FAIL: unexpected finding");
}
