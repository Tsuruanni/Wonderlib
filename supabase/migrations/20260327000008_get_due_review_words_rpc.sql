-- Single RPC to fetch vocabulary words due for review (replaces 2 sequential queries)
CREATE OR REPLACE FUNCTION get_due_review_words(
  p_user_id UUID,
  p_limit INT DEFAULT 30
)
RETURNS SETOF vocabulary_words
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT vw.*
  FROM vocabulary_words vw
  INNER JOIN vocabulary_progress vp ON vp.word_id = vw.id
  WHERE vp.user_id = p_user_id
    AND vp.next_review_at <= NOW()
  ORDER BY vp.next_review_at ASC
  LIMIT p_limit;
$$;
