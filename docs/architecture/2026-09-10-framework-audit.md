# General search framework audit

Status: implemented as Provider API 2, 2026-09-10. See 2026-09-10-provider-framework.md for the selected design and scope.

## Product contract

Lychee is a general in-game search platform. Business examples are acceptance samples, not a closed list of supported domains. A search Provider owns discoverable data and declared interactions; the Host owns indexing, ranking, presentation, selection, action validation and lifecycle. Built-in and third-party integrations must pass through the same public interface.

The framework must support independently varying data and interaction capabilities: indexed or query-produced entries, synchronous or delayed results, updates, information-only entries, ordinary and protected actions, multiple actions, drag declarations, views and restoration. Existing WoW restrictions remain enforced by the Host's execution mechanisms; arbitrary callbacks do not gain protected authority.

## Confirmed defects, before interface redesign

- P1: old source handles captured only the source ID and could overwrite a new extension instance registered with the same ID. Reproduced using public registration, Unregister, re-registration and old CommitSnapshot. Source operations must check the captured owner instance and lifecycle, including deferred commits.
- P1: public handles exposed `_entry`, and registration drafts exposed mutable implementation tables. Public objects must retain their implementation in closures.
- P2: descriptors and records were retained by reference and mutated with internal ownership fields. Inputs must be validated, copied at ingress and never modified in the caller's ownership.
- P2: Supports could throw on malformed revisions. Public version negotiation must return false for unsupported input.
- P2: a 129-record literal failed the generic 128-field limit while a snapshot callback returning identical records passed. Source batch capacity must be validated independently and consistently.
- P2: public ready subscriptions lacked cancellation; callback references could remain held before readiness.
- P2: built-in spell registration bypassed the public facade; SDK type declarations, documentation and the third-party view fixture diverged from runtime contracts.
- P2: recent history stored bare IDs, could cross owners, and could not restore dynamic or Command results. Actions and drag capabilities also need a broader, explicitly versioned model.

The confirmed defects were addressed in the current implementation. The chosen interface is Provider API 2, with no old SDK adapter or data migration. Built-in and third-party integration tests exercise the public facade.
