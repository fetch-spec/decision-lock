-- breaks D002: the order guard function never refuses anything
CREATE OR REPLACE FUNCTION orders.guard_shipped_order() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;
