# Decision log: orders example

Source of truth. Each entry is one decision. Tests are named after the id.

- **D001** An order status is exactly one of `new`, `paid`, `shipped`, `cancelled`. Anything else, including a different letter case or no value, is refused.
- **D002** A shipped order is frozen. Neither the order nor any of its lines can be changed or deleted, and no line can be added to it.
- **D003** Customers read orders only through functions that take their customer id. A customer never sees another customer's order, and customers have no direct table access.
