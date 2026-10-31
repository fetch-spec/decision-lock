# Decision log (example, made-up "catalog" domain)

The written source of truth. One decision per entry, stable ids, plain words. A decision that changes later is edited here first, and its test follows.

- **D001** A product code is unique and is stored in upper case. Two codes that differ only in letter case are the same code.
- **D002** A product has exactly one price per currency. A price is never negative.
- **D003** Discontinued products stay searchable by code and link to the product that replaces them. They are never deleted.
- **D004** A published catalog version is sealed. No row of the version, and no row under it, can change after publishing; a correction is a new version.
- **D005** Shoppers read the catalog only through functions that take their shop id. A shop never sees another shop's hidden products.
- **D006** The legacy "bundle" feature is cut. No table, column, view or function named like it may exist in any schema.
- **D007** Prices are re-synced nightly from the supplier feed. (Not built yet: the sync job does not exist.)
- **D008** The team reviews the sealed catalog every quarter. (Process only: nothing to test in the database.)
- **D009** Every price change is written to the audit log with who changed it and the old value.
- **D010** Product descriptions are kept in the original language of the supplier, never auto-translated in the database.

Classification the builder would write: D001-D006 and D009 DB-BUILT, D007 DB-NOT-BUILT (test fails "D007: not built yet"), D008 NOT-DB, D010 DB-BUILT (no translation function or column exists).
