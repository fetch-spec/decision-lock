-- breaks D003: get_order still takes the customer id but no longer filters on it
CREATE OR REPLACE FUNCTION orders.get_order(p_customer_id int, p_order_id bigint)
RETURNS SETOF orders.customer_order LANGUAGE sql STABLE AS $$
  SELECT * FROM orders.customer_order WHERE id = p_order_id
$$;
