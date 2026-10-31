-- breaks D001: statuses are compared case-insensitively, so SHIPPED and Paid pass
ALTER TABLE orders.customer_order DROP CONSTRAINT customer_order_status_chk;
ALTER TABLE orders.customer_order ADD CONSTRAINT customer_order_status_chk
  CHECK (lower(status) IN ('new', 'paid', 'shipped', 'cancelled'));
