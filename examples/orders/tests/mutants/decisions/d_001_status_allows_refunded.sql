-- breaks D001: an extra status value is allowed
ALTER TABLE orders.customer_order DROP CONSTRAINT customer_order_status_chk;
ALTER TABLE orders.customer_order ADD CONSTRAINT customer_order_status_chk
  CHECK (status IN ('new', 'paid', 'shipped', 'cancelled', 'refunded'));
