-- D002: a shipped order is frozen: the order and every line under it cannot be changed or deleted, and no line can be added.
-- General rule: columns and child tables are read from the catalog, so a new column or child table is covered without edits.
BEGIN;

-- fixture: one order that becomes shipped, with one line; one open order with one line (the control)
INSERT INTO orders.customer_order (id, customer_id, status, total_cents) VALUES (900, 1, 'new', 500), (901, 1, 'new', 500);
INSERT INTO orders.order_line (id, order_id, sku, qty) VALUES (900, 900, 'A', 1), (901, 901, 'B', 1);
UPDATE orders.customer_order SET status = 'shipped' WHERE id = 900;

CREATE TEMP TABLE child_tables AS
  SELECT c.conrelid::regclass::text AS tbl, c.conrelid AS oid
  FROM pg_constraint c WHERE c.contype = 'f' AND c.confrelid = 'orders.customer_order'::regclass;
CREATE TEMP TABLE frozen_cols AS
  SELECT 'orders.customer_order'::text AS tbl, 'id = 900'::text AS pick, attname::text AS col
    FROM pg_attribute WHERE attrelid = 'orders.customer_order'::regclass AND attnum > 0 AND NOT attisdropped
  UNION ALL
  SELECT ct.tbl, 'order_id = 900', a.attname::text
    FROM child_tables ct JOIN pg_attribute a ON a.attrelid = ct.oid AND a.attnum > 0 AND NOT a.attisdropped;

SELECT plan((SELECT count(*)::int FROM frozen_cols) + (SELECT count(*)::int FROM child_tables) + 5);

SELECT cmp_ok((SELECT count(*)::int FROM child_tables), '>=', 1, 'D002-01 child tables of the order are found from the catalog');

-- every column of the order and of every child table: setting it to its own value is still refused
SELECT throws_ok(format('UPDATE %s SET %I = %I WHERE %s', tbl, col, col, pick),
                 'P0001', 'shipped order is frozen', 'D002-02 update of ' || tbl || '.' || col || ' is refused')
FROM frozen_cols;

-- deleting from every child table is refused
SELECT throws_ok(format('DELETE FROM %s WHERE order_id = 900', tbl), 'P0001', 'shipped order is frozen',
                 'D002-03 delete from ' || tbl || ' is refused')
FROM child_tables;

SELECT throws_ok($q$DELETE FROM orders.customer_order WHERE id = 900$q$, 'P0001', 'shipped order is frozen',
                 'D002-04 deleting the shipped order is refused');
SELECT throws_ok($q$INSERT INTO orders.order_line (order_id, sku, qty) VALUES (900, 'C', 1)$q$, 'P0001', 'shipped order is frozen',
                 'D002-05 adding a line to a shipped order is refused');
SELECT throws_ok($q$UPDATE orders.order_line SET order_id = 901 WHERE id = 900$q$, 'P0001', 'shipped order is frozen',
                 'D002-06 moving a line out of a shipped order is refused');

-- control: the open order is still editable, so the guard is not simply blocking everything
SELECT lives_ok($q$UPDATE orders.customer_order SET note = 'ok' WHERE id = 901$q$, 'D002-07 an open order can still be changed');
SELECT * FROM finish();
ROLLBACK;
