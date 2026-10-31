-- breaks D002: the order guard only notices changes to the note column
CREATE OR REPLACE FUNCTION orders.guard_shipped_order() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'shipped' AND NEW.note IS DISTINCT FROM OLD.note THEN RAISE EXCEPTION 'shipped order is frozen'; END IF;
    RETURN NEW;
  END IF;
  IF OLD.status = 'shipped' THEN RAISE EXCEPTION 'shipped order is frozen'; END IF;
  RETURN OLD;
END $$;
