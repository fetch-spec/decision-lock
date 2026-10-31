-- breaks D002: lines of a shipped order are no longer protected
DROP TRIGGER order_line_frozen ON orders.order_line;
