-- breaks D003: customers get direct read access to the table
GRANT SELECT ON orders.customer_order TO app_customer;
