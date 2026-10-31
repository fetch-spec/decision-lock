-- breaks D003: a new lookup that takes no customer id is open to customers
CREATE FUNCTION orders.find_order(p_order_id bigint) RETURNS SETOF orders.customer_order LANGUAGE sql STABLE AS $$
  SELECT * FROM orders.customer_order WHERE id = p_order_id
$$;
GRANT EXECUTE ON FUNCTION orders.find_order(bigint) TO app_customer;
