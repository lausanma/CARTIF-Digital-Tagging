# TEMPLATE ONLY: fill these functions after the consortium confirms contracts.
# Activate with DIGITAL_TAGGING_ADAPTER_SCRIPT = absolute path to this script,
# DIGITAL_TAGGING_READ_ADAPTER = biospace and WRITE_ADAPTER = biospace.
# This intentionally fails instead of reporting a fake successful integration.
register_batch_adapter("biospace",
  read = function(pilot, batch_id) {
    # 1. Query agreed sources using pilot + batch + interval where required.
    # 2. Map external payloads to new_batch_record(pilot, batch_id) shape.
    # 3. Preserve origins, units and actual timestamps. Global values use
    #    time_scope='batch', timestamp=NULL. Never invent measurement times.
    # 4. Return NULL only for a confirmed absent record, NOT on HTTP errors.
    stop("Implement read mapping after API contracts are confirmed.")
  },
  write = function(record) {
    # Map to the agreed target schema, authenticate via environment/secret store,
    # use timeouts, check HTTP status and retain server version/ETag for conflicts.
    # Return the canonical saved record ONLY after confirmed persistence.
    # If saving across services, handle partial failures before returning success.
    # No implicit writes into Batch DT: respect Batch DT Creator ownership.
    stop("Implement write mapping after destination is confirmed.")
  }
)
