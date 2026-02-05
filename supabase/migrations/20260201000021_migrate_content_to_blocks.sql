-- Migration: Migrate existing chapter.content to content_blocks
-- This migration parses plain text content and creates structured blocks
-- Also handles vocabulary position recalculation

-- =============================================
-- MIGRATION FUNCTION
-- =============================================
CREATE OR REPLACE FUNCTION migrate_chapter_to_content_blocks(p_chapter_id UUID)
RETURNS void AS $$
DECLARE
    v_content TEXT;
    v_paragraphs TEXT[];
    v_paragraph TEXT;
    v_order_index INTEGER := 0;
    v_char_offset INTEGER := 0;
    v_vocabulary JSONB;
    v_vocab_item JSONB;
    v_new_vocab JSONB := '[]'::JSONB;
    v_vocab_start INTEGER;
    v_vocab_end INTEGER;
    v_block_start INTEGER;
    v_block_end INTEGER;
    v_inline_activities RECORD;
BEGIN
    -- Get chapter content and vocabulary
    SELECT content, vocabulary INTO v_content, v_vocabulary
    FROM chapters
    WHERE id = p_chapter_id;

    -- Skip if no content
    IF v_content IS NULL OR v_content = '' THEN
        RETURN;
    END IF;

    -- Split content by double newlines (paragraphs)
    v_paragraphs := regexp_split_to_array(v_content, E'\n\n+');

    -- Create text blocks for each paragraph
    FOREACH v_paragraph IN ARRAY v_paragraphs
    LOOP
        -- Skip empty paragraphs
        v_paragraph := TRIM(v_paragraph);
        IF v_paragraph = '' THEN
            CONTINUE;
        END IF;

        -- Calculate block boundaries in original content
        v_block_start := v_char_offset;
        v_block_end := v_char_offset + LENGTH(v_paragraph);

        -- Insert text block
        INSERT INTO content_blocks (chapter_id, order_index, type, text)
        VALUES (p_chapter_id, v_order_index, 'text', v_paragraph);

        -- Check if there's an inline activity after this paragraph
        FOR v_inline_activities IN
            SELECT id FROM inline_activities
            WHERE chapter_id = p_chapter_id
            AND after_paragraph_index = v_order_index
            ORDER BY id
        LOOP
            v_order_index := v_order_index + 1;
            INSERT INTO content_blocks (chapter_id, order_index, type, activity_id)
            VALUES (p_chapter_id, v_order_index, 'activity', v_inline_activities.id);
        END LOOP;

        v_order_index := v_order_index + 1;
        -- Account for double newline separator
        v_char_offset := v_block_end + 2;
    END LOOP;

    -- Mark chapter as using content_blocks
    UPDATE chapters
    SET use_content_blocks = TRUE
    WHERE id = p_chapter_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- MIGRATE ALL EXISTING CHAPTERS
-- =============================================
DO $$
DECLARE
    v_chapter RECORD;
BEGIN
    -- Only migrate chapters that have content and haven't been migrated
    FOR v_chapter IN
        SELECT id FROM chapters
        WHERE content IS NOT NULL
        AND content != ''
        AND (use_content_blocks IS NULL OR use_content_blocks = FALSE)
    LOOP
        PERFORM migrate_chapter_to_content_blocks(v_chapter.id);
        RAISE NOTICE 'Migrated chapter: %', v_chapter.id;
    END LOOP;
END $$;

-- =============================================
-- HELPER FUNCTION: Calculate vocabulary positions for a block
-- =============================================
-- Note: Vocabulary positions are relative to the block's text, not chapter content
-- This function can be called after migration to recalculate positions
CREATE OR REPLACE FUNCTION recalculate_block_vocabulary_positions(p_block_id UUID)
RETURNS void AS $$
DECLARE
    v_block_type VARCHAR(20);
    v_block_text TEXT;
    v_chapter_id UUID;
    v_vocab JSONB;
    v_vocab_item JSONB;
    v_new_vocab JSONB := '[]'::JSONB;
    v_word TEXT;
    v_word_pos INTEGER;
BEGIN
    -- Get block info
    SELECT type, text, chapter_id
    INTO v_block_type, v_block_text, v_chapter_id
    FROM content_blocks
    WHERE id = p_block_id;

    IF v_block_type != 'text' OR v_block_text IS NULL THEN
        RETURN;
    END IF;

    -- Get chapter vocabulary
    SELECT vocabulary INTO v_vocab
    FROM chapters
    WHERE id = v_chapter_id;

    IF v_vocab IS NULL THEN
        RETURN;
    END IF;

    -- For each vocabulary word in chapter, check if it exists in this block
    FOR v_vocab_item IN SELECT * FROM jsonb_array_elements(v_vocab)
    LOOP
        v_word := v_vocab_item->>'word';
        -- Case-insensitive search
        v_word_pos := position(lower(v_word) in lower(v_block_text));

        IF v_word_pos > 0 THEN
            -- Adjust to 0-based index
            v_word_pos := v_word_pos - 1;

            v_new_vocab := v_new_vocab || jsonb_build_object(
                'word', v_word,
                'meaning', v_vocab_item->>'meaning',
                'phonetic', v_vocab_item->>'phonetic',
                'startIndex', v_word_pos,
                'endIndex', v_word_pos + LENGTH(v_word)
            );
        END IF;
    END LOOP;

    -- Note: vocabulary is stored at chapter level, not block level
    -- This function is informational - actual vocabulary lookup happens at runtime
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION migrate_chapter_to_content_blocks IS 'Migrates chapter plain text content to structured content_blocks';
COMMENT ON FUNCTION recalculate_block_vocabulary_positions IS 'Helper to find vocabulary positions within a specific block';
