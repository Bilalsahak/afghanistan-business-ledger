# Financial misuse review

Review date: 2026-09-15

## Fixed in this release

- **Silent daily-record rewriting:** Direct UPDATE and DELETE are removed for every application user, including admins. Corrections are append-only adjustments.
- **Correction without evidence:** Every correction requires a new camera image, a reason, the original snapshot, the requester, and timestamps.
- **Self-approval:** A requester cannot approve their own daily correction or partner-money request.
- **Hidden field changes during approval:** Admin approval grants cover only decision fields. Amounts, dates, partners, reasons, evidence, and requesters cannot be altered during review.
- **Evidence deletion:** Receipt, notebook, and correction images cannot be deleted after a database record references them. Only failed/unreferenced uploads can be cleaned up by their uploader.
- **Backdated daily records:** Ordinary operators can create records only for today or yesterday. Owner backfills remain exceptional and audited.
- **Correction flooding:** Only one pending correction per user per daily record is allowed, and ordinary users have a seven-day correction window.
- **Negative corrected values:** Database enforcement rejects an adjustment that would make any daily financial field negative.
- **Untraceable applied corrections:** Approval updates the effective record through a protected database trigger while preserving the original snapshot, adjustment, approval note, evidence, and before/after audit event.

## Important remaining controls

### High priority

1. **Customer-level Qarz ledger** — Daily Qarz is currently a total. A dishonest or mistaken user could name no customer, making collection difficult to verify. Add customer name/phone, amount, due date, repayment history, and running balance.
2. **Monthly-close approval** — Managers can prepare a monthly close that immediately appears in reporting. Change this to Prepared → Owner reviewed → Locked, with inventory-count evidence.
3. **Opening-cash continuity** — A user can enter opening cash independently. Add an automatic comparison against the previous closing cash and require a documented cash-transfer explanation for differences.
4. **Receipt-to-total reconciliation** — Receipts are supporting evidence but their totals do not currently have to match purchases, expenses, sales, or Qarz. Add category reconciliation and exception warnings.

### Medium priority

5. **Qarz customer confirmation** — For large credit sales, require customer identity and optionally a photographed signature/thumbprint page.
6. **Inventory movement detail** — Only purchase value and month-end value are recorded. Theft or shrinkage cannot be isolated without item/quantity movement or periodic spot counts.
7. **Owner account resilience** — Enable leaked-password protection and MFA for owner/admin accounts. Keep at least two independent owners only if both are trusted.
8. **Session revocation** — Rejecting a user does not immediately invalidate an already-issued token. Keep tokens short-lived and revoke sessions when removing sensitive access.
9. **Large-value thresholds** — Require two owners or written partner evidence for large partner withdrawals, profit distributions, and corrections over an agreed AFN threshold.

### Operational controls

10. Compare physical cash to the app every day.
11. Review pending corrections and partner-money requests from the evidence, never from the explanation alone.
12. Export and archive the workbook monthly outside the application.
13. Perform a surprise inventory spot count and Qarz-customer check periodically.
