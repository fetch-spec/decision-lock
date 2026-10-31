-- breaks D001: the status check is gone
ALTER TABLE orders.customer_order DROP CONSTRAINT customer_order_status_chk;
