"""Implementations for ui_customer component."""

impl CustomerApp.checkStatus -> None {
    if not consumer_input.strip() {
        return;
    }
    result = root spawn get_status(consumer_no=consumer_input.strip());
    if result.reports and len(result.reports) > 0 {
        status_info = result.reports[0];
        status_checked = True;
    }
}

impl CustomerApp.sendComplaint -> None {
    if not report_text.strip() and not consumer_input.strip() {
        return;
    }
    _ = root spawn submit_complaint(text=report_text, consumer_no=consumer_input.strip());
    complaint_submitted = True;
    sms_messages = sms_messages + [
        f"GridMedic: Outage report received for consumer {consumer_input}. Ticket logged and queued for assessment."
    ];
    report_text = "";
}
