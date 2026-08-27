# Error message mapping

- Upstream baseline: `27781b3ef4da6c836e5b6a4db90ff0d4bfb1964c`
- Added: 2026-08-25
- Reason: keep upstream relay errors available to administrators while returning
  channel-specific public messages to API clients and non-admin log views.
- Scope: channel configuration, relay error presentation, usage-log visibility,
  and the administrator log-details UI.
- Review on upstream update: compare upstream channel schema, relay error output,
  log sanitization, and usage-log components before reapplying.
- Rollback: remove the `error_message_mapping` channel field and its UI, remove
  the final-response mapping call and mapped log metadata, then rebuild New API.

This customization deliberately preserves the original upstream error for retry,
channel-disable, violation, and administrator diagnostics. Mapping is applied only
at public response and non-admin log presentation boundaries.
