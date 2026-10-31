-- D003: customers read orders only through functions that take their customer id; they never see another customer's order
-- and have no direct table access. General rule: every function in schema orders that app_customer can run is found from pg_proc.
BEGIN;

INSERT INTO orders.customer_order (id, customer_id, status, total_cents) VALUES (910, 1, 'new', 100), (911, 2, 'paid', 200);

CREATE TEMP TABLE customer_fns AS
  SELECT p.oid, p.proname::text AS name, p.proargnames
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'orders' AND p.prokind = 'f' AND has_function_privilege('app_customer', p.oid, 'EXECUTE')
    AND p.prorettype <> 'trigger'::regtype;

SELECT plan((SELECT count(*)::int FROM customer_fns) + 7);

SELECT cmp_ok((SELECT count(*)::int FROM customer_fns), '>=', 2, 'D003-01 the customer-callable functions are found from the catalog');

-- every customer-callable function takes a customer id
SELECT ok(proargnames @> ARRAY['p_customer_id'], 'D003-02 orders.' || name || ' takes p_customer_id')
FROM customer_fns;

-- behaviour on each read path: own order visible, someone else's order and a wrong id both return nothing
SELECT is((SELECT count(*)::int FROM orders.get_order(1, 910)), 1, 'D003-03 get_order returns the customer''s own order');
SELECT is((SELECT count(*)::int FROM orders.get_order(1, 911)), 0, 'D003-04 get_order hides another customer''s order');
SELECT is((SELECT count(*)::int FROM orders.list_orders(1)), 1, 'D003-05 list_orders lists only the customer''s own orders');
SELECT is((SELECT count(*)::int FROM orders.list_orders(1, 'paid')), 0, 'D003-06 list_orders with a status filter still hides other customers');

-- no direct table access
SELECT is((SELECT bool_or(has_table_privilege('app_customer', c.oid, 'SELECT'))
           FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'orders' AND c.relkind IN ('r', 'v', 'm', 'p')), false,
          'D003-07 app_customer cannot select from any table or view in schema orders');
SELECT is((SELECT bool_or(has_table_privilege('app_customer', c.oid, 'INSERT,UPDATE,DELETE'))
           FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'orders' AND c.relkind IN ('r', 'v', 'm', 'p')), false,
          'D003-08 app_customer cannot write to any table or view in schema orders');
SELECT * FROM finish();
ROLLBACK;
