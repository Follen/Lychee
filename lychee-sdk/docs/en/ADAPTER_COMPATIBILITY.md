# Third-party adapters

[Contents](README.md) · [简体中文](../zh-CN/ADAPTER_COMPATIBILITY.md)

A unified Provider interface removes Host business branches, not upstream dependencies. When an upstream addon lacks a stable public interface, concentrate version-sensitive access in your provider's adapter and record source version, missing capabilities and supported scope. Follow [client selection](CLIENT_VARIANTS.md) and [performance rules](PERFORMANCE.md).

## Ellesmere example

Lychee's internal `addon/Lychee/Providers/Ellesmere/Adapter.lua` centralizes upstream access. Provider code owns querying, stable IDs, capture budgets, ranking and cancellation. This repository path and the following upstream fields are implementation evidence, not additional SDK fields or files third parties must import.

| Upstream capability | Purpose | Unavailable behavior |
| --- | --- | --- |
| EllesmereUI / EnsureLoaded / _deferredLoaded / _modules | Load/read modules on explicit EUI demand | Report unavailable; no fabricated directory/UI substitutes |
| config.pages | Validate page at query/resolve/click | Removed targets become unavailable; no persistent mutable-page cache |
| L / TAB_LABEL_OVERRIDES | Localized/page labels | Use original text on invalid/missing/throwing translation |
| _RegisterSearchEntry / _searchIndexSuppress | Passive native setting capture | Page directory still works; do not claim all settings captured |
| NavigateToElementSettings | Page/section/control navigation | EUI_UNAVAILABLE on failure; keep search open and do not remember success |
| EnsureUnlockCore / OpenUnlockMode / _unlockActive | Unlock action | Combat/failure remains unavailable |

Native navigation owns first-open delay/page construction. Search never runs dynamic tooltips, prebuilds pages, writes settings or calls an internal index prebuilder. Preserve argument order: module, page, section, selector callback, label. An upstream false return is not automatically a defined failure; thrown errors are isolated.

An irreversible hook captures only during the owner's active lifetime and for the current upstream object. Owner end drops captured records and short-circuits. Turning search off changes participation only, not capture lifetime. Mark hooked only after success so failure can retry. Replacing an already-hooked function on the same object still needs explicit version adaptation; repeated hooks/polling do not prove future compatibility.

## Cache and correctness

Distinguish immutable declarations from mutable state. Without reliable version/invalidation events, do not cache whole page directories between queries. During batches, table identity/length does not prove content unchanged; resolve/actions revalidate pages. Materialize full records only for top-K candidates while preserving scores, IDs, ordering and limits. Synchronous validation may be reused within the same candidate step.

Capture caps at 4096 entries/2 MiB text, batches at 32 items or 1 ms. Query cancellation drops query work/references; owner end drops background capture. No idle polling.

## Version evidence and acceptance

Historical evidence: sourceId=ellesmereui, product=main, requestedRef=latest, commit `271ffc30d3265d9f77746b0e15224d918f0fafcb`. EllesmereUI.lua:5565 is EnsureLoaded; :9316 is NavigateToElementSettings; EllesmereUI_GlobalSearch.lua:22 is _RegisterSearchEntry. Consult the recorded wowdoc evidence for exact source positions.

On upstream update, check the exact source version, then test missing/throwing APIs, retry, changing pages and actual navigation args. Compare complete results/order/resolve/actions, not merely absence of errors. The historical 44-case comparison used baseline 3b0af04 and does not certify a later upstream or current real client.

Repository commands: `lua tests/providers/ellesmere_adapter.lua`, `lua tests/providers/ellesmere_equivalence.lua`, `lua tests/providers/ellesmere_provider.lua`. The standalone SDK does not include these tests. Real first-open/section/selector/unlock behavior needs separate client verification.
