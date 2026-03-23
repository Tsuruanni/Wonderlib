-- Automatically set attempt_number on insert via trigger
-- Replaces client-side COUNT which had a race condition

CREATE OR REPLACE FUNCTION set_quiz_attempt_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.attempt_number := COALESCE(
    (SELECT MAX(attempt_number) FROM book_quiz_results
     WHERE user_id = NEW.user_id AND quiz_id = NEW.quiz_id),
    0
  ) + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_quiz_attempt_number
  BEFORE INSERT ON book_quiz_results
  FOR EACH ROW
  EXECUTE FUNCTION set_quiz_attempt_number();

-- Safety net: prevent duplicate attempt numbers under concurrent inserts
ALTER TABLE book_quiz_results
  ADD CONSTRAINT uq_quiz_attempt UNIQUE (user_id, quiz_id, attempt_number);
