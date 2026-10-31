-- D001: an order status is exactly new, paid, shipped or cancelled; anything else is refused.
BEGIN;
SELECT plan(13);

-- every decided value is accepted
SELECT lives_ok(format($q$INSERT INTO orders.customer_order (customer_id, status, total_cents) VALUES (1, %L, 0)$q$, s),
                'D001-01 status ' || s || ' is accepted')
FROM unnest(ARRAY['new', 'paid', 'shipped', 'cancelled']) AS s;

-- values that must be refused: unknown, wrong case, padded, empty
SELECT throws_ok(format($q$INSERT INTO orders.customer_order (customer_id, status, total_cents) VALUES (1, %L, 0)$q$, s),
                 '23514', NULL, 'D001-02 status ' || quote_literal(s) || ' is refused')
FROM unnest(ARRAY['refunded', 'SHIPPED', 'Paid', ' new', '']) AS s;

SELECT throws_ok($q$INSERT INTO orders.customer_order (customer_id, status, total_cents) VALUES (1, NULL, 0)$q$,
                 '23502', NULL, 'D001-03 a null status is refused');

-- an update probe only proves something if a row matched, so first check a row exists
SELECT is((SELECT count(*)::int FROM orders.customer_order WHERE status = 'new' AND customer_id = 1), 1,
          'D001-04 the update probe has a row to hit');
SELECT throws_ok($q$UPDATE orders.customer_order SET status = 'lost' WHERE customer_id = 1 AND status = 'new'$q$,
                 '23514', NULL, 'D001-05 changing an existing order to an unknown status is refused');

SELECT is((SELECT column_default FROM information_schema.columns
           WHERE table_schema = 'orders' AND table_name = 'customer_order' AND column_name = 'status'),
          $$'new'::text$$, 'D001-06 a new order starts as new');
SELECT * FROM finish();
ROLLBACK;
