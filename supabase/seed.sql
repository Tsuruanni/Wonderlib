-- Seed Data for ReadEng (Wonderlib)
-- Run with: supabase db reset (applies migrations + seed)

-- =============================================
-- BADGES
-- =============================================
INSERT INTO badges (name, slug, description, icon, category, condition_type, condition_value, xp_reward) VALUES
('First Steps', 'first-steps', 'Complete your first book', '📖', 'reading', 'books_completed', 1, 50),
('Bookworm', 'bookworm', 'Complete 5 books', '🐛', 'reading', 'books_completed', 5, 200),
('Library Master', 'library-master', 'Complete 20 books', '📚', 'reading', 'books_completed', 20, 500),
('Streak Starter', 'streak-starter', 'Maintain a 3-day reading streak', '🔥', 'streak', 'streak_days', 3, 30),
('Streak Master', 'streak-master', 'Maintain a 7-day reading streak', '🔥', 'streak', 'streak_days', 7, 100),
('Streak Legend', 'streak-legend', 'Maintain a 30-day reading streak', '🔥', 'streak', 'streak_days', 30, 500),
('Word Explorer', 'word-explorer', 'Master 10 vocabulary words', '🔤', 'vocabulary', 'vocabulary_learned', 10, 50),
('Vocabulary Champion', 'vocabulary-champion', 'Master 50 vocabulary words', '🏆', 'vocabulary', 'vocabulary_learned', 50, 150),
('Word Master', 'word-master', 'Master 200 vocabulary words', '👑', 'vocabulary', 'vocabulary_learned', 200, 500),
('Perfect Score', 'perfect-score', 'Get 100% on an activity', '⭐', 'activities', 'perfect_scores', 1, 75),
('Perfectionist', 'perfectionist', 'Get 10 perfect scores', '⭐', 'activities', 'perfect_scores', 10, 200),
('Rising Star', 'rising-star', 'Earn 500 XP', '🌟', 'xp', 'xp_total', 500, 50),
('Scholar', 'scholar', 'Earn 2000 XP', '🎓', 'xp', 'xp_total', 2000, 100),
('Expert', 'expert', 'Earn 5000 XP', '🏅', 'xp', 'xp_total', 5000, 200),
('Legend', 'legend', 'Earn 10000 XP', '👑', 'xp', 'xp_total', 10000, 500),
('Level 5', 'level-5', 'Reach Level 5', '5️⃣', 'level', 'level_completed', 5, 100),
('Level 10', 'level-10', 'Reach Level 10', '🔟', 'level', 'level_completed', 10, 250);

-- =============================================
-- VOCABULARY WORDS
-- =============================================

-- Common Words Level 1 (A1)
INSERT INTO vocabulary_words (id, word, phonetic, meaning_tr, meaning_en, level, categories, synonyms, antonyms, example_sentences) VALUES
('11111111-0001-0001-0001-000000000001', 'happy', '/ˈhæpi/', 'mutlu', 'feeling or showing pleasure', 'A1', ARRAY['adjectives', 'emotions'], ARRAY['joyful', 'cheerful'], ARRAY['sad', 'unhappy'], ARRAY['I am happy today.', 'The happy children played in the park.']),
('11111111-0001-0001-0001-000000000002', 'big', '/bɪɡ/', 'büyük', 'of considerable size', 'A1', ARRAY['adjectives', 'size'], ARRAY['large', 'huge'], ARRAY['small', 'tiny'], ARRAY['The elephant is big.', 'We live in a big house.']),
('11111111-0001-0001-0001-000000000003', 'run', '/rʌn/', 'koşmak', 'to move quickly on foot', 'A1', ARRAY['verbs', 'movement'], ARRAY['sprint', 'dash'], ARRAY['walk', 'stop'], ARRAY['I run every morning.', 'The dog likes to run.']),
('11111111-0001-0001-0001-000000000004', 'eat', '/iːt/', 'yemek', 'to put food in your mouth', 'A1', ARRAY['verbs', 'food'], ARRAY['consume', 'devour'], ARRAY['fast', 'starve'], ARRAY['I eat breakfast at 8.', 'What do you want to eat?']),
('11111111-0001-0001-0001-000000000005', 'book', '/bʊk/', 'kitap', 'written or printed pages bound together', 'A1', ARRAY['nouns', 'education'], ARRAY['novel', 'text'], ARRAY[]::TEXT[], ARRAY['I read a book.', 'This is my favorite book.']),
('11111111-0001-0001-0001-000000000006', 'water', '/ˈwɔːtər/', 'su', 'a clear liquid essential for life', 'A1', ARRAY['nouns', 'nature'], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY['I drink water.', 'The water is cold.']),
('11111111-0001-0001-0001-000000000007', 'friend', '/frend/', 'arkadaş', 'a person you like and enjoy spending time with', 'A1', ARRAY['nouns', 'relationships'], ARRAY['companion', 'buddy'], ARRAY['enemy', 'foe'], ARRAY['She is my friend.', 'I play with my friends.']),
('11111111-0001-0001-0001-000000000008', 'school', '/skuːl/', 'okul', 'a place where children learn', 'A1', ARRAY['nouns', 'education'], ARRAY['academy'], ARRAY[]::TEXT[], ARRAY['I go to school.', 'My school is near my house.']),
('11111111-0001-0001-0001-000000000009', 'play', '/pleɪ/', 'oynamak', 'to engage in an activity for enjoyment', 'A1', ARRAY['verbs', 'activities'], ARRAY['have fun'], ARRAY['work'], ARRAY['Children play in the garden.', 'Do you want to play?']),
('11111111-0001-0001-0001-000000000010', 'good', '/ɡʊd/', 'iyi', 'of high quality or satisfactory', 'A1', ARRAY['adjectives', 'quality'], ARRAY['great', 'excellent'], ARRAY['bad', 'poor'], ARRAY['This is good food.', 'You did a good job.']);

-- Common Words Level 2 (A2)
INSERT INTO vocabulary_words (id, word, phonetic, meaning_tr, meaning_en, level, categories, synonyms, antonyms, example_sentences) VALUES
('11111111-0001-0002-0001-000000000001', 'beautiful', '/ˈbjuːtɪfəl/', 'güzel', 'pleasing to the senses', 'A2', ARRAY['adjectives', 'describing'], ARRAY['lovely', 'gorgeous'], ARRAY['ugly', 'plain'], ARRAY['The sunset is beautiful.', 'She has a beautiful voice.']),
('11111111-0001-0002-0001-000000000002', 'important', '/ɪmˈpɔːtənt/', 'önemli', 'of great significance or value', 'A2', ARRAY['adjectives', 'quality'], ARRAY['significant', 'crucial'], ARRAY['unimportant', 'trivial'], ARRAY['This is an important meeting.', 'Health is important.']),
('11111111-0001-0002-0001-000000000003', 'understand', '/ˌʌndərˈstænd/', 'anlamak', 'to perceive the meaning of', 'A2', ARRAY['verbs', 'mental'], ARRAY['comprehend', 'grasp'], ARRAY['misunderstand'], ARRAY['I understand the lesson.', 'Do you understand me?']),
('11111111-0001-0002-0001-000000000004', 'remember', '/rɪˈmembər/', 'hatırlamak', 'to recall information from memory', 'A2', ARRAY['verbs', 'mental'], ARRAY['recall', 'recollect'], ARRAY['forget'], ARRAY['I remember your name.', 'Please remember to call.']),
('11111111-0001-0002-0001-000000000005', 'different', '/ˈdɪfrənt/', 'farklı', 'not the same as another', 'A2', ARRAY['adjectives', 'comparing'], ARRAY['distinct', 'unique'], ARRAY['same', 'similar'], ARRAY['We have different opinions.', 'This book is different.']);

-- Animals (A1)
INSERT INTO vocabulary_words (id, word, phonetic, meaning_tr, meaning_en, level, categories, synonyms, antonyms, example_sentences) VALUES
('11111111-0002-0001-0001-000000000001', 'elephant', '/ˈelɪfənt/', 'fil', 'a very large animal with a trunk and tusks', 'A1', ARRAY['nouns', 'animals'], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY['The elephant has big ears.', 'Elephants live in Africa and Asia.']),
('11111111-0002-0001-0001-000000000002', 'butterfly', '/ˈbʌtərflaɪ/', 'kelebek', 'an insect with colorful wings', 'A1', ARRAY['nouns', 'animals', 'insects'], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY['The butterfly is colorful.', 'A butterfly landed on the flower.']),
('11111111-0002-0001-0001-000000000003', 'rabbit', '/ˈræbɪt/', 'tavşan', 'a small animal with long ears', 'A1', ARRAY['nouns', 'animals'], ARRAY['bunny'], ARRAY[]::TEXT[], ARRAY['The rabbit jumps.', 'Rabbits eat carrots.']),
('11111111-0002-0001-0001-000000000004', 'dolphin', '/ˈdɒlfɪn/', 'yunus', 'a smart sea mammal', 'A1', ARRAY['nouns', 'animals', 'sea'], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY['Dolphins are friendly.', 'The dolphin swims fast.']),
('11111111-0002-0001-0001-000000000005', 'tiger', '/ˈtaɪɡər/', 'kaplan', 'a large wild cat with stripes', 'A1', ARRAY['nouns', 'animals', 'wild'], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY['The tiger is strong.', 'Tigers live in Asia.']);

-- Feelings & Emotions (A2)
INSERT INTO vocabulary_words (id, word, phonetic, meaning_tr, meaning_en, level, categories, synonyms, antonyms, example_sentences) VALUES
('11111111-0003-0001-0001-000000000001', 'excited', '/ɪkˈsaɪtɪd/', 'heyecanlı', 'feeling very happy and enthusiastic', 'A2', ARRAY['adjectives', 'emotions'], ARRAY['thrilled', 'eager'], ARRAY['bored', 'calm'], ARRAY['I am excited about the trip.', 'The excited fans cheered.']),
('11111111-0003-0001-0001-000000000002', 'nervous', '/ˈnɜːrvəs/', 'gergin', 'feeling worried or slightly afraid', 'A2', ARRAY['adjectives', 'emotions'], ARRAY['anxious', 'worried'], ARRAY['calm', 'relaxed'], ARRAY['I feel nervous before exams.', 'She was nervous about the interview.']),
('11111111-0003-0001-0001-000000000003', 'proud', '/praʊd/', 'gururlu', 'feeling pleased about achievements', 'A2', ARRAY['adjectives', 'emotions'], ARRAY['satisfied', 'pleased'], ARRAY['ashamed'], ARRAY['I am proud of you.', 'She felt proud of her work.']),
('11111111-0003-0001-0001-000000000004', 'surprised', '/sərˈpraɪzd/', 'şaşırmış', 'feeling amazed by something unexpected', 'A2', ARRAY['adjectives', 'emotions'], ARRAY['amazed', 'astonished'], ARRAY['unsurprised'], ARRAY['I was surprised by the gift.', 'She looked surprised.']),
('11111111-0003-0001-0001-000000000005', 'grateful', '/ˈɡreɪtfəl/', 'minnettar', 'feeling thankful', 'A2', ARRAY['adjectives', 'emotions'], ARRAY['thankful', 'appreciative'], ARRAY['ungrateful'], ARRAY['I am grateful for your help.', 'We should be grateful.']);

-- Content Block Book Words (A1-A2)
INSERT INTO vocabulary_words (id, word, phonetic, meaning_tr, meaning_en, level, categories, synonyms, antonyms, example_sentences) VALUES
('11111111-0004-0001-0001-000000000001', 'garden', '/ˈɡɑːrdən/', 'bahçe', 'a piece of ground for growing plants', 'A1', ARRAY['nouns', 'nature'], ARRAY['yard', 'backyard'], ARRAY[]::TEXT[], ARRAY['I play in the garden.', 'The garden has many flowers.']),
('11111111-0004-0001-0001-000000000002', 'secret', '/ˈsiːkrət/', 'gizli', 'something kept hidden from others', 'A1', ARRAY['adjectives', 'nouns'], ARRAY['hidden', 'private'], ARRAY['public', 'known'], ARRAY['This is a secret place.', 'Can you keep a secret?']),
('11111111-0004-0001-0001-000000000003', 'flower', '/ˈflaʊər/', 'çiçek', 'the colorful part of a plant', 'A1', ARRAY['nouns', 'nature'], ARRAY['bloom', 'blossom'], ARRAY[]::TEXT[], ARRAY['The flower is red.', 'I picked a flower for my mom.']),
('11111111-0004-0001-0001-000000000004', 'wish', '/wɪʃ/', 'dilek', 'a desire or hope for something', 'A1', ARRAY['nouns', 'verbs'], ARRAY['hope', 'desire'], ARRAY[]::TEXT[], ARRAY['I wish for a puppy.', 'Make a wish!']),
('11111111-0004-0001-0001-000000000005', 'rocket', '/ˈrɒkɪt/', 'roket', 'a vehicle that travels into space', 'A1', ARRAY['nouns', 'space'], ARRAY['spacecraft'], ARRAY[]::TEXT[], ARRAY['The rocket goes to space.', 'I want to ride a rocket.']),
('11111111-0004-0001-0001-000000000006', 'space', '/speɪs/', 'uzay', 'the area beyond Earth', 'A1', ARRAY['nouns', 'space'], ARRAY['cosmos', 'universe'], ARRAY[]::TEXT[], ARRAY['Stars are in space.', 'I dream of going to space.']),
('11111111-0004-0001-0001-000000000007', 'planet', '/ˈplænɪt/', 'gezegen', 'a large round object in space', 'A1', ARRAY['nouns', 'space'], ARRAY['world'], ARRAY[]::TEXT[], ARRAY['Earth is a planet.', 'Mars is the red planet.']),
('11111111-0004-0001-0001-000000000008', 'Earth', '/ɜːrθ/', 'Dünya', 'the planet we live on', 'A1', ARRAY['nouns', 'space'], ARRAY['world', 'globe'], ARRAY[]::TEXT[], ARRAY['We live on Earth.', 'Earth is beautiful from space.']),
('11111111-0004-0001-0001-000000000009', 'star', '/stɑːr/', 'yıldız', 'a bright point of light in the sky', 'A1', ARRAY['nouns', 'space'], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY['The star is bright.', 'I see many stars at night.']),
('11111111-0004-0001-0001-000000000010', 'robot', '/ˈroʊbɒt/', 'robot', 'a machine that can do tasks', 'A2', ARRAY['nouns', 'technology'], ARRAY['machine', 'android'], ARRAY[]::TEXT[], ARRAY['The robot can walk.', 'I have a toy robot.']),
('11111111-0004-0001-0001-000000000011', 'factory', '/ˈfæktəri/', 'fabrika', 'a building where things are made', 'A2', ARRAY['nouns', 'places'], ARRAY['plant', 'workshop'], ARRAY[]::TEXT[], ARRAY['Cars are made in a factory.', 'The factory is very big.']),
('11111111-0004-0001-0001-000000000012', 'problem', '/ˈprɒbləm/', 'sorun', 'something difficult to solve', 'A2', ARRAY['nouns'], ARRAY['issue', 'trouble'], ARRAY['solution'], ARRAY['This is a big problem.', 'Can you solve the problem?']),
('11111111-0004-0001-0001-000000000013', 'hero', '/ˈhɪəroʊ/', 'kahraman', 'a brave person who helps others', 'A2', ARRAY['nouns'], ARRAY['champion'], ARRAY['villain'], ARRAY['He is a hero.', 'Heroes save people.']),
('11111111-0004-0001-0001-000000000014', 'brave', '/breɪv/', 'cesur', 'not afraid of danger', 'A2', ARRAY['adjectives'], ARRAY['courageous', 'fearless'], ARRAY['scared', 'afraid'], ARRAY['Be brave!', 'The brave knight saved the princess.']),
('11111111-0004-0001-0001-000000000015', 'ocean', '/ˈoʊʃən/', 'okyanus', 'a very large body of salt water', 'A1', ARRAY['nouns', 'nature', 'sea'], ARRAY['sea'], ARRAY[]::TEXT[], ARRAY['The ocean is blue.', 'Fish live in the ocean.']),
('11111111-0004-0001-0001-000000000016', 'coral', '/ˈkɒrəl/', 'mercan', 'a hard underwater structure', 'A2', ARRAY['nouns', 'sea'], ARRAY['reef'], ARRAY[]::TEXT[], ARRAY['Coral is colorful.', 'Fish hide in the coral.']),
('11111111-0004-0001-0001-000000000017', 'treasure', '/ˈtreʒər/', 'hazine', 'valuable things like gold', 'A2', ARRAY['nouns'], ARRAY['riches', 'wealth'], ARRAY[]::TEXT[], ARRAY['Pirates look for treasure.', 'We found a treasure chest!']);

-- =============================================
-- WORD LISTS
-- =============================================
INSERT INTO word_lists (id, name, description, level, category, word_count, is_system) VALUES
('22222222-0001-0001-0001-000000000001', 'Common Words Level 1', 'Essential everyday vocabulary for beginners', 'A1', 'common_words', 10, true),
('22222222-0001-0001-0001-000000000002', 'Common Words Level 2', 'Building your vocabulary foundation', 'A2', 'common_words', 5, true),
('22222222-0001-0001-0001-000000000003', 'Animals', 'Learn the names of animals in English', 'A1', 'thematic', 5, true),
('22222222-0001-0001-0001-000000000004', 'Feelings & Emotions', 'Express how you feel in English', 'A2', 'thematic', 5, true);

-- =============================================
-- WORD LIST ITEMS (link words to lists)
-- =============================================

-- Common Words Level 1
INSERT INTO word_list_items (word_list_id, word_id, order_index) VALUES
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000001', 1),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000002', 2),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000003', 3),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000004', 4),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000005', 5),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000006', 6),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000007', 7),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000008', 8),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000009', 9),
('22222222-0001-0001-0001-000000000001', '11111111-0001-0001-0001-000000000010', 10);

-- Common Words Level 2
INSERT INTO word_list_items (word_list_id, word_id, order_index) VALUES
('22222222-0001-0001-0001-000000000002', '11111111-0001-0002-0001-000000000001', 1),
('22222222-0001-0001-0001-000000000002', '11111111-0001-0002-0001-000000000002', 2),
('22222222-0001-0001-0001-000000000002', '11111111-0001-0002-0001-000000000003', 3),
('22222222-0001-0001-0001-000000000002', '11111111-0001-0002-0001-000000000004', 4),
('22222222-0001-0001-0001-000000000002', '11111111-0001-0002-0001-000000000005', 5);

-- Animals
INSERT INTO word_list_items (word_list_id, word_id, order_index) VALUES
('22222222-0001-0001-0001-000000000003', '11111111-0002-0001-0001-000000000001', 1),
('22222222-0001-0001-0001-000000000003', '11111111-0002-0001-0001-000000000002', 2),
('22222222-0001-0001-0001-000000000003', '11111111-0002-0001-0001-000000000003', 3),
('22222222-0001-0001-0001-000000000003', '11111111-0002-0001-0001-000000000004', 4),
('22222222-0001-0001-0001-000000000003', '11111111-0002-0001-0001-000000000005', 5);

-- Feelings & Emotions
INSERT INTO word_list_items (word_list_id, word_id, order_index) VALUES
('22222222-0001-0001-0001-000000000004', '11111111-0003-0001-0001-000000000001', 1),
('22222222-0001-0001-0001-000000000004', '11111111-0003-0001-0001-000000000002', 2),
('22222222-0001-0001-0001-000000000004', '11111111-0003-0001-0001-000000000003', 3),
('22222222-0001-0001-0001-000000000004', '11111111-0003-0001-0001-000000000004', 4),
('22222222-0001-0001-0001-000000000004', '11111111-0003-0001-0001-000000000005', 5);

-- =============================================
-- SAMPLE SCHOOL (for development)
-- =============================================
INSERT INTO schools (id, name, code, status, subscription_tier) VALUES
('33333333-0001-0001-0001-000000000001', 'Demo School', 'DEMO123', 'active', 'pro');

-- =============================================
-- SAMPLE CLASS (for development)
-- =============================================
INSERT INTO classes (id, school_id, name, grade, academic_year) VALUES
('77777777-0001-0001-0001-000000000001', '33333333-0001-0001-0001-000000000001', '5-A', '5', '2024-2025');

-- =============================================
-- TEST USERS (for development)
-- All passwords: Test1234
-- =============================================

-- 1. FRESH USER: New student, 0 XP, no progress
-- Email: fresh@demo.com
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  role, aud, confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '88888888-0001-0001-0001-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'fresh@demo.com',
  crypt('Test1234', gen_salt('bf')),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  '{"first_name": "Fresh", "last_name": "Student", "student_number": "2024001", "school_code": "DEMO123", "role": "student"}',
  NOW(), NOW(), 'authenticated', 'authenticated', '', '', '', ''
);

UPDATE profiles SET
  first_name = 'Fresh', last_name = 'Student', role = 'student',
  email = 'fresh@demo.com',
  school_id = '33333333-0001-0001-0001-000000000001',
  class_id = '77777777-0001-0001-0001-000000000001',
  student_number = '2024001', xp = 0, current_streak = 0, longest_streak = 0
WHERE id = '88888888-0001-0001-0001-000000000001';

-- 2. ACTIVE USER: Mid-progress student, 500 XP, reading 1 book
-- Email: active@demo.com
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  role, aud, confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '88888888-0001-0001-0001-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'active@demo.com',
  crypt('Test1234', gen_salt('bf')),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  '{"first_name": "Active", "last_name": "Student", "student_number": "2024002", "school_code": "DEMO123", "role": "student"}',
  NOW(), NOW(), 'authenticated', 'authenticated', '', '', '', ''
);

UPDATE profiles SET
  first_name = 'Active', last_name = 'Student', role = 'student',
  email = 'active@demo.com',
  school_id = '33333333-0001-0001-0001-000000000001',
  class_id = '77777777-0001-0001-0001-000000000001',
  student_number = '2024002', xp = 500, current_streak = 3, longest_streak = 5
WHERE id = '88888888-0001-0001-0001-000000000002';

-- 3. ADVANCED USER: High-progress student, 5000 XP, many activities completed
-- Email: advanced@demo.com (for duplicate XP testing)
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  role, aud, confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '88888888-0001-0001-0001-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'advanced@demo.com',
  crypt('Test1234', gen_salt('bf')),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  '{"first_name": "Advanced", "last_name": "Student", "student_number": "2024003", "school_code": "DEMO123", "role": "student"}',
  NOW(), NOW(), 'authenticated', 'authenticated', '', '', '', ''
);

UPDATE profiles SET
  first_name = 'Advanced', last_name = 'Student', role = 'student',
  email = 'advanced@demo.com',
  school_id = '33333333-0001-0001-0001-000000000001',
  class_id = '77777777-0001-0001-0001-000000000001',
  student_number = '2024003', xp = 5000, current_streak = 14, longest_streak = 21
WHERE id = '88888888-0001-0001-0001-000000000003';

-- 4. TEACHER USER: For dashboard testing
-- Email: teacher@demo.com
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  role, aud, confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '88888888-0001-0001-0001-000000000004',
  '00000000-0000-0000-0000-000000000000',
  'teacher@demo.com',
  crypt('Test1234', gen_salt('bf')),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  '{"first_name": "Demo", "last_name": "Teacher", "school_code": "DEMO123", "role": "teacher"}',
  NOW(), NOW(), 'authenticated', 'authenticated', '', '', '', ''
);

UPDATE profiles SET
  first_name = 'Demo', last_name = 'Teacher', role = 'teacher',
  email = 'teacher@demo.com',
  school_id = '33333333-0001-0001-0001-000000000001',
  xp = 0, current_streak = 0, longest_streak = 0
WHERE id = '88888888-0001-0001-0001-000000000004';

-- 5. ADMIN USER: For admin panel
-- Email: admin@demo.com
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  role, aud, confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '88888888-0001-0001-0001-000000000005',
  '00000000-0000-0000-0000-000000000000',
  'admin@demo.com',
  crypt('Test1234', gen_salt('bf')),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  '{"first_name": "System", "last_name": "Admin", "role": "admin"}',
  NOW(), NOW(), 'authenticated', 'authenticated', '', '', '', ''
);

UPDATE profiles SET
  first_name = 'System', last_name = 'Admin', role = 'admin',
  email = 'admin@demo.com',
  school_id = '33333333-0001-0001-0001-000000000001',
  xp = 0, current_streak = 0, longest_streak = 0
WHERE id = '88888888-0001-0001-0001-000000000005';

-- =============================================
-- VOCABULARY PROGRESS (words learned by users - content block book words)
-- Uses SM-2 spaced repetition: status, ease_factor, interval_days, repetitions
-- =============================================
INSERT INTO vocabulary_progress (id, user_id, word_id, status, ease_factor, interval_days, repetitions, next_review_at, last_reviewed_at) VALUES
-- ACTIVE USER: Learning some content block words
('bbbbbbbb-0001-0001-0001-000000000001', '88888888-0001-0001-0001-000000000002', '11111111-0004-0001-0001-000000000001', 'learning', 2.50, 1, 2, NOW() + INTERVAL '1 day', NOW() - INTERVAL '1 day'),
('bbbbbbbb-0001-0001-0001-000000000002', '88888888-0001-0001-0001-000000000002', '11111111-0004-0001-0001-000000000002', 'new_word', 2.50, 0, 1, NOW() + INTERVAL '4 hours', NOW() - INTERVAL '2 days'),

-- ADVANCED USER: Many content block words mastered
('bbbbbbbb-0001-0001-0001-000000000003', '88888888-0001-0001-0001-000000000003', '11111111-0004-0001-0001-000000000001', 'mastered', 2.80, 30, 10, NOW() + INTERVAL '30 days', NOW() - INTERVAL '5 days'),
('bbbbbbbb-0001-0001-0001-000000000004', '88888888-0001-0001-0001-000000000003', '11111111-0004-0001-0001-000000000002', 'mastered', 2.70, 30, 8, NOW() + INTERVAL '30 days', NOW() - INTERVAL '5 days'),
('bbbbbbbb-0001-0001-0001-000000000005', '88888888-0001-0001-0001-000000000003', '11111111-0004-0001-0001-000000000003', 'mastered', 2.90, 30, 12, NOW() + INTERVAL '30 days', NOW() - INTERVAL '3 days'),
('bbbbbbbb-0001-0001-0001-000000000006', '88888888-0001-0001-0001-000000000003', '11111111-0004-0001-0001-000000000004', 'reviewing', 2.60, 14, 7, NOW() + INTERVAL '14 days', NOW() - INTERVAL '2 days'),
('bbbbbbbb-0001-0001-0001-000000000007', '88888888-0001-0001-0001-000000000003', '11111111-0002-0001-0001-000000000002', 'reviewing', 2.60, 14, 6, NOW() + INTERVAL '14 days', NOW() - INTERVAL '6 days'),
('bbbbbbbb-0001-0001-0001-000000000008', '88888888-0001-0001-0001-000000000003', '11111111-0004-0001-0001-000000000005', 'learning', 2.50, 3, 3, NOW() - INTERVAL '1 day', NOW() - INTERVAL '4 days'),
('bbbbbbbb-0001-0001-0001-000000000009', '88888888-0001-0001-0001-000000000003', '11111111-0004-0001-0001-000000000006', 'learning', 2.55, 3, 3, NOW() - INTERVAL '2 days', NOW() - INTERVAL '5 days');

-- =============================================
-- CONTENT BLOCK BOOKS (New books with rich content)
-- =============================================

-- BOOK 1: The Magic Garden (A1 - Elementary)
INSERT INTO books (id, title, slug, description, cover_url, level, genre, age_group, estimated_minutes, word_count, chapter_count, status, metadata, published_at) VALUES
('44444444-0002-0001-0001-000000000001', 'The Magic Garden', 'the-magic-garden', 'Join Lily on a magical adventure through an enchanted garden where flowers can talk and butterflies grant wishes!', 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=400', 'A1', 'Fiction', 'elementary', 20, 1200, 3, 'published', '{"author": "Emma Stories", "year": 2024}', NOW());

-- Chapters for Magic Garden (with use_content_blocks = true)
INSERT INTO chapters (id, book_id, title, order_index, content, word_count, estimated_minutes, vocabulary, use_content_blocks) VALUES
('55555555-0002-0001-0001-000000000001', '44444444-0002-0001-0001-000000000001', 'The Secret Gate', 1, NULL, 400, 5, '[]', true),
('55555555-0002-0001-0001-000000000002', '44444444-0002-0001-0001-000000000001', 'The Talking Flowers', 2, NULL, 400, 5, '[]', true),
('55555555-0002-0001-0001-000000000003', '44444444-0002-0001-0001-000000000001', 'The Wish Butterfly', 3, NULL, 400, 5, '[]', true);

-- Inline Activities for Magic Garden
INSERT INTO inline_activities (id, chapter_id, type, after_paragraph_index, content, xp_reward, vocabulary_words) VALUES
-- Chapter 1 activities
('66666666-0004-0001-0001-000000000001', '55555555-0002-0001-0001-000000000001', 'word_translation', 0,
'{"word": "garden", "correctAnswer": "bahce", "options": ["bahce", "ev", "okul"]}', 5, ARRAY['11111111-0004-0001-0001-000000000001']),
('66666666-0004-0001-0001-000000000002', '55555555-0002-0001-0001-000000000001', 'true_false', 0,
'{"statement": "Lily found a small gate behind the bushes.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0004-0001-0001-000000000003', '55555555-0002-0001-0001-000000000001', 'word_translation', 0,
'{"word": "secret", "correctAnswer": "gizli", "options": ["gizli", "buyuk", "kucuk"]}', 5, ARRAY['11111111-0004-0001-0001-000000000002']),
-- Chapter 2 activities
('66666666-0004-0002-0001-000000000001', '55555555-0002-0001-0001-000000000002', 'word_translation', 0,
'{"word": "flower", "correctAnswer": "cicek", "options": ["cicek", "agac", "yaprak"]}', 5, ARRAY['11111111-0004-0001-0001-000000000003']),
('66666666-0004-0002-0001-000000000002', '55555555-0002-0001-0001-000000000002', 'true_false', 0,
'{"statement": "The roses could sing songs.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0004-0002-0001-000000000003', '55555555-0002-0001-0001-000000000002', 'find_words', 0,
'{"instruction": "Which flowers did Lily meet?", "options": ["Rose", "Sunflower", "Cactus", "Daisy"], "correctAnswers": ["Rose", "Sunflower", "Daisy"]}', 5, ARRAY[]::TEXT[]),
-- Chapter 3 activities
('66666666-0004-0003-0001-000000000001', '55555555-0002-0001-0001-000000000003', 'word_translation', 0,
'{"word": "butterfly", "correctAnswer": "kelebek", "options": ["kelebek", "kus", "bocek"]}', 5, ARRAY['11111111-0002-0001-0001-000000000002']),
('66666666-0004-0003-0001-000000000002', '55555555-0002-0001-0001-000000000003', 'true_false', 0,
'{"statement": "The butterfly had golden wings.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0004-0003-0001-000000000003', '55555555-0002-0001-0001-000000000003', 'word_translation', 0,
'{"word": "wish", "correctAnswer": "dilek", "options": ["dilek", "ruya", "hediye"]}', 5, ARRAY['11111111-0004-0001-0001-000000000004']);

-- Content Blocks for Magic Garden - Chapter 1
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000001-0001-0001-0001-000000000001', '55555555-0002-0001-0001-000000000001', 1, 'text',
'One sunny morning, a little girl named Lily walked into her grandmother''s backyard. She loved playing there because it was full of beautiful flowers and tall trees.', NULL, NULL, NULL),
('cb000001-0001-0001-0001-000000000002', '55555555-0002-0001-0001-000000000001', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=600', 'A beautiful garden with colorful flowers', NULL),
('cb000001-0001-0001-0001-000000000003', '55555555-0002-0001-0001-000000000001', 3, 'text',
'Today, something was different. Behind the rose bushes, Lily saw something she had never noticed before - a small wooden gate covered in green vines.', NULL, NULL, NULL),
('cb000001-0001-0001-0001-000000000004', '55555555-0002-0001-0001-000000000001', 4, 'activity',
NULL, NULL, NULL, '66666666-0004-0001-0001-000000000001'),
('cb000001-0001-0001-0001-000000000005', '55555555-0002-0001-0001-000000000001', 5, 'text',
'"How strange!" Lily whispered. "I have never seen this gate before." She touched the old wood carefully. The gate was warm, like it had been sitting in the sunshine for hours.', NULL, NULL, NULL),
('cb000001-0001-0001-0001-000000000006', '55555555-0002-0001-0001-000000000001', 6, 'image',
NULL, 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600', 'A mysterious wooden gate in the garden', NULL),
('cb000001-0001-0001-0001-000000000007', '55555555-0002-0001-0001-000000000001', 7, 'activity',
NULL, NULL, NULL, '66666666-0004-0001-0001-000000000002'),
('cb000001-0001-0001-0001-000000000008', '55555555-0002-0001-0001-000000000001', 8, 'text',
'Lily pushed the gate gently. To her surprise, it opened with a soft creak. On the other side, she saw the most beautiful garden she had ever seen!', NULL, NULL, NULL),
('cb000001-0001-0001-0001-000000000009', '55555555-0002-0001-0001-000000000001', 9, 'activity',
NULL, NULL, NULL, '66666666-0004-0001-0001-000000000003');

-- Content Blocks for Magic Garden - Chapter 2
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000001-0002-0001-0001-000000000001', '55555555-0002-0001-0001-000000000002', 1, 'text',
'The garden was magical! Flowers of every color grew everywhere - red roses, yellow sunflowers, purple violets, and white daisies. But these were not ordinary flowers.', NULL, NULL, NULL),
('cb000001-0002-0001-0001-000000000002', '55555555-0002-0001-0001-000000000002', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=600', 'Colorful flowers in the magic garden', NULL),
('cb000001-0002-0001-0001-000000000003', '55555555-0002-0001-0001-000000000002', 3, 'activity',
NULL, NULL, NULL, '66666666-0004-0002-0001-000000000001'),
('cb000001-0002-0001-0001-000000000004', '55555555-0002-0001-0001-000000000002', 4, 'text',
'"Hello, little girl!" said a red rose in a sweet voice. Lily jumped back in surprise. "Did you... did you just talk?" she asked.', NULL, NULL, NULL),
('cb000001-0002-0001-0001-000000000005', '55555555-0002-0001-0001-000000000002', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1455659817273-f96807779a8a?w=600', 'A beautiful red rose', NULL),
('cb000001-0002-0001-0001-000000000006', '55555555-0002-0001-0001-000000000002', 6, 'text',
'"Of course we can talk!" laughed the rose. "We can also sing!" Then all the flowers started singing a beautiful song together. The sunflowers hummed the melody while the daisies added harmony.', NULL, NULL, NULL),
('cb000001-0002-0001-0001-000000000007', '55555555-0002-0001-0001-000000000002', 7, 'activity',
NULL, NULL, NULL, '66666666-0004-0002-0001-000000000002'),
('cb000001-0002-0001-0001-000000000008', '55555555-0002-0001-0001-000000000002', 8, 'text',
'Lily listened with wonder. She had never heard anything so beautiful in her whole life. The flowers danced in the gentle breeze as they sang.', NULL, NULL, NULL),
('cb000001-0002-0001-0001-000000000009', '55555555-0002-0001-0001-000000000002', 9, 'activity',
NULL, NULL, NULL, '66666666-0004-0002-0001-000000000003');

-- Content Blocks for Magic Garden - Chapter 3
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000001-0003-0001-0001-000000000001', '55555555-0002-0001-0001-000000000003', 1, 'text',
'After the song ended, Lily noticed something flying toward her. It was the most beautiful butterfly she had ever seen. Its wings were golden and sparkled in the sunlight.', NULL, NULL, NULL),
('cb000001-0003-0001-0001-000000000002', '55555555-0002-0001-0001-000000000003', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1559715521-1d3a14c23b65?w=600', 'A beautiful golden butterfly', NULL),
('cb000001-0003-0001-0001-000000000003', '55555555-0002-0001-0001-000000000003', 3, 'activity',
NULL, NULL, NULL, '66666666-0004-0003-0001-000000000001'),
('cb000001-0003-0001-0001-000000000004', '55555555-0002-0001-0001-000000000003', 4, 'text',
'"I am the Wish Butterfly," it said, landing softly on Lily''s finger. "I can grant one wish to anyone who finds the magic garden. What do you wish for?"', NULL, NULL, NULL),
('cb000001-0003-0001-0001-000000000005', '55555555-0002-0001-0001-000000000003', 5, 'activity',
NULL, NULL, NULL, '66666666-0004-0003-0001-000000000002'),
('cb000001-0003-0001-0001-000000000006', '55555555-0002-0001-0001-000000000003', 6, 'text',
'Lily thought carefully. She could wish for toys, or candy, or anything! But then she smiled. "I wish to come back and visit my new friends whenever I want," she said.', NULL, NULL, NULL),
('cb000001-0003-0001-0001-000000000007', '55555555-0002-0001-0001-000000000003', 7, 'image',
NULL, 'https://images.unsplash.com/photo-1518882605630-8992a0919e90?w=600', 'Lily smiling in the garden', NULL),
('cb000001-0003-0001-0001-000000000008', '55555555-0002-0001-0001-000000000003', 8, 'activity',
NULL, NULL, NULL, '66666666-0004-0003-0001-000000000003'),
('cb000001-0003-0001-0001-000000000009', '55555555-0002-0001-0001-000000000003', 9, 'text',
'The butterfly''s wings glowed brightly. "Your wish is granted!" it said. "The magic garden will always welcome you." And from that day on, Lily visited her flower friends every single day.', NULL, NULL, NULL);

-- =============================================
-- BOOK 2: Space Adventure (A1 - Elementary)
-- =============================================
INSERT INTO books (id, title, slug, description, cover_url, level, genre, age_group, estimated_minutes, word_count, chapter_count, status, metadata, published_at) VALUES
('44444444-0002-0002-0001-000000000001', 'Space Adventure', 'space-adventure', 'Join astronaut Max on an exciting journey through the solar system! Visit planets, meet friendly aliens, and discover the wonders of space.', 'https://images.unsplash.com/photo-1446776877081-d282a0f896e2?w=400', 'A1', 'Fiction', 'elementary', 25, 1500, 3, 'published', '{"author": "Star Writer", "year": 2024}', NOW());

-- Chapters for Space Adventure
INSERT INTO chapters (id, book_id, title, order_index, content, word_count, estimated_minutes, vocabulary, use_content_blocks) VALUES
('55555555-0002-0002-0001-000000000001', '44444444-0002-0002-0001-000000000001', 'Blast Off!', 1, NULL, 500, 6, '[]', true),
('55555555-0002-0002-0001-000000000002', '44444444-0002-0002-0001-000000000001', 'The Red Planet', 2, NULL, 500, 6, '[]', true),
('55555555-0002-0002-0001-000000000003', '44444444-0002-0002-0001-000000000001', 'Home Again', 3, NULL, 500, 6, '[]', true);

-- Inline Activities for Space Adventure
INSERT INTO inline_activities (id, chapter_id, type, after_paragraph_index, content, xp_reward, vocabulary_words) VALUES
-- Chapter 1 activities
('66666666-0005-0001-0001-000000000001', '55555555-0002-0002-0001-000000000001', 'word_translation', 0,
'{"word": "rocket", "correctAnswer": "roket", "options": ["roket", "araba", "ucak"]}', 5, ARRAY['11111111-0004-0001-0001-000000000005']),
('66666666-0005-0001-0001-000000000002', '55555555-0002-0002-0001-000000000001', 'true_false', 0,
'{"statement": "Max is an astronaut.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0005-0001-0001-000000000003', '55555555-0002-0002-0001-000000000001', 'word_translation', 0,
'{"word": "space", "correctAnswer": "uzay", "options": ["uzay", "deniz", "orman"]}', 5, ARRAY['11111111-0004-0001-0001-000000000006']),
-- Chapter 2 activities
('66666666-0005-0002-0001-000000000001', '55555555-0002-0002-0001-000000000002', 'word_translation', 0,
'{"word": "planet", "correctAnswer": "gezegen", "options": ["gezegen", "yildiz", "ay"]}', 5, ARRAY['11111111-0004-0001-0001-000000000007']),
('66666666-0005-0002-0001-000000000002', '55555555-0002-0002-0001-000000000002', 'true_false', 0,
'{"statement": "Mars is called the Red Planet.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0005-0002-0001-000000000003', '55555555-0002-0002-0001-000000000002', 'find_words', 0,
'{"instruction": "What did Max see on Mars?", "options": ["Mountains", "Rivers", "Red rocks", "Aliens"], "correctAnswers": ["Mountains", "Red rocks"]}', 5, ARRAY[]::TEXT[]),
-- Chapter 3 activities
('66666666-0005-0003-0001-000000000001', '55555555-0002-0002-0001-000000000003', 'word_translation', 0,
'{"word": "Earth", "correctAnswer": "Dunya", "options": ["Dunya", "Mars", "Ay"]}', 5, ARRAY['11111111-0004-0001-0001-000000000008']),
('66666666-0005-0003-0001-000000000002', '55555555-0002-0002-0001-000000000003', 'true_false', 0,
'{"statement": "Max wanted to go on another adventure.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0005-0003-0001-000000000003', '55555555-0002-0002-0001-000000000003', 'word_translation', 0,
'{"word": "star", "correctAnswer": "yildiz", "options": ["yildiz", "bulut", "gunes"]}', 5, ARRAY['11111111-0004-0001-0001-000000000009']);

-- Content Blocks for Space Adventure - Chapter 1
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000002-0001-0001-0001-000000000001', '55555555-0002-0002-0001-000000000001', 1, 'text',
'Max was the youngest astronaut in the world. He was only ten years old! Today was a very special day - his first mission to space.', NULL, NULL, NULL),
('cb000002-0001-0001-0001-000000000002', '55555555-0002-0002-0001-000000000001', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1457364887197-9150188c107b?w=600', 'A young astronaut in a space suit', NULL),
('cb000002-0001-0001-0001-000000000003', '55555555-0002-0002-0001-000000000001', 3, 'activity',
NULL, NULL, NULL, '66666666-0005-0001-0001-000000000001'),
('cb000002-0001-0001-0001-000000000004', '55555555-0002-0002-0001-000000000001', 4, 'text',
'"Are you ready, Max?" asked Captain Luna. "Yes!" Max shouted excitedly. He put on his space helmet and climbed into the shiny silver rocket.', NULL, NULL, NULL),
('cb000002-0001-0001-0001-000000000005', '55555555-0002-0002-0001-000000000001', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7?w=600', 'A rocket ready for launch', NULL),
('cb000002-0001-0001-0001-000000000006', '55555555-0002-0002-0001-000000000001', 6, 'activity',
NULL, NULL, NULL, '66666666-0005-0001-0001-000000000002'),
('cb000002-0001-0001-0001-000000000007', '55555555-0002-0002-0001-000000000001', 7, 'text',
'"10... 9... 8... 7... 6... 5... 4... 3... 2... 1... BLAST OFF!" The rocket shot up into the sky like a giant firework. Max felt himself being pushed back into his seat.', NULL, NULL, NULL),
('cb000002-0001-0001-0001-000000000008', '55555555-0002-0002-0001-000000000001', 8, 'image',
NULL, 'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=600', 'Rocket blasting off into space', NULL),
('cb000002-0001-0001-0001-000000000009', '55555555-0002-0002-0001-000000000001', 9, 'activity',
NULL, NULL, NULL, '66666666-0005-0001-0001-000000000003'),
('cb000002-0001-0001-0001-000000000010', '55555555-0002-0002-0001-000000000001', 10, 'text',
'Soon, the sky turned from blue to black. Max looked out the window and saw millions of twinkling stars. "Wow!" he whispered. "Space is so beautiful!"', NULL, NULL, NULL);

-- Content Blocks for Space Adventure - Chapter 2
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000002-0002-0001-0001-000000000001', '55555555-0002-0002-0001-000000000002', 1, 'text',
'After flying for three days, Max finally saw it - Mars, the Red Planet! It looked like a giant orange ball floating in space.', NULL, NULL, NULL),
('cb000002-0002-0001-0001-000000000002', '55555555-0002-0002-0001-000000000002', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1614728894747-a83421e2b9c9?w=600', 'The planet Mars', NULL),
('cb000002-0002-0001-0001-000000000003', '55555555-0002-0002-0001-000000000002', 3, 'activity',
NULL, NULL, NULL, '66666666-0005-0002-0001-000000000001'),
('cb000002-0002-0001-0001-000000000004', '55555555-0002-0002-0001-000000000002', 4, 'text',
'The rocket landed gently on the red surface. Max put on his special boots and stepped outside. The ground was covered in red rocks and red dust.', NULL, NULL, NULL),
('cb000002-0002-0001-0001-000000000005', '55555555-0002-0002-0001-000000000002', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1545156521-77bd85671d30?w=600', 'Red rocky surface of Mars', NULL),
('cb000002-0002-0001-0001-000000000006', '55555555-0002-0002-0001-000000000002', 6, 'activity',
NULL, NULL, NULL, '66666666-0005-0002-0001-000000000002'),
('cb000002-0002-0001-0001-000000000007', '55555555-0002-0002-0001-000000000002', 7, 'text',
'"Look at those mountains!" Max pointed at the huge red mountains in the distance. They were much bigger than any mountains on Earth. Mars was amazing!', NULL, NULL, NULL),
('cb000002-0002-0001-0001-000000000008', '55555555-0002-0002-0001-000000000002', 8, 'activity',
NULL, NULL, NULL, '66666666-0005-0002-0001-000000000003'),
('cb000002-0002-0001-0001-000000000009', '55555555-0002-0002-0001-000000000002', 9, 'text',
'Max collected some rocks to bring back home. Scientists would study them to learn more about Mars. He felt like the luckiest boy in the universe!', NULL, NULL, NULL);

-- Content Blocks for Space Adventure - Chapter 3
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000002-0003-0001-0001-000000000001', '55555555-0002-0002-0001-000000000003', 1, 'text',
'It was time to go home. Max waved goodbye to Mars and climbed back into the rocket. "Earth, here we come!" said Captain Luna.', NULL, NULL, NULL),
('cb000002-0003-0001-0001-000000000002', '55555555-0002-0002-0001-000000000003', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600', 'Earth from space', NULL),
('cb000002-0003-0001-0001-000000000003', '55555555-0002-0002-0001-000000000003', 3, 'activity',
NULL, NULL, NULL, '66666666-0005-0003-0001-000000000001'),
('cb000002-0003-0001-0001-000000000004', '55555555-0002-0002-0001-000000000003', 4, 'text',
'Three days later, Max saw the most beautiful sight - Earth! It was blue and green and white. It looked like a precious marble floating in the darkness.', NULL, NULL, NULL),
('cb000002-0003-0001-0001-000000000005', '55555555-0002-0002-0001-000000000003', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1614732414444-096e5f1122d5?w=600', 'Beautiful view of Earth', NULL),
('cb000002-0003-0001-0001-000000000006', '55555555-0002-0002-0001-000000000003', 6, 'text',
'The rocket landed safely. Max''s family was waiting for him. "Welcome home, Space Explorer!" they cheered. Max hugged everyone tight.', NULL, NULL, NULL),
('cb000002-0003-0001-0001-000000000007', '55555555-0002-0002-0001-000000000003', 7, 'activity',
NULL, NULL, NULL, '66666666-0005-0003-0001-000000000002'),
('cb000002-0003-0001-0001-000000000008', '55555555-0002-0002-0001-000000000003', 8, 'text',
'That night, Max looked up at the stars. "One day," he said, "I will visit every planet in the solar system!" And he knew that his space adventures were just beginning.', NULL, NULL, NULL),
('cb000002-0003-0001-0001-000000000009', '55555555-0002-0002-0001-000000000003', 9, 'image',
NULL, 'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=600', 'Beautiful night sky with stars', NULL),
('cb000002-0003-0001-0001-000000000010', '55555555-0002-0002-0001-000000000003', 10, 'activity',
NULL, NULL, NULL, '66666666-0005-0003-0001-000000000003');

-- =============================================
-- BOOK 3: The Brave Little Robot (A2 - Elementary)
-- =============================================
INSERT INTO books (id, title, slug, description, cover_url, level, genre, age_group, estimated_minutes, word_count, chapter_count, status, metadata, published_at) VALUES
('44444444-0002-0003-0001-000000000001', 'The Brave Little Robot', 'the-brave-little-robot', 'Beep is a small robot who dreams of doing big things. When the city needs help, can this little robot save the day?', 'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=400', 'A2', 'Fiction', 'elementary', 30, 1800, 3, 'published', '{"author": "Tech Tales", "year": 2024}', NOW());

-- Chapters for Brave Little Robot
INSERT INTO chapters (id, book_id, title, order_index, content, word_count, estimated_minutes, vocabulary, use_content_blocks) VALUES
('55555555-0002-0003-0001-000000000001', '44444444-0002-0003-0001-000000000001', 'The Robot Factory', 1, NULL, 600, 8, '[]', true),
('55555555-0002-0003-0001-000000000002', '44444444-0002-0003-0001-000000000001', 'The Big Problem', 2, NULL, 600, 8, '[]', true),
('55555555-0002-0003-0001-000000000003', '44444444-0002-0003-0001-000000000001', 'A Hero is Born', 3, NULL, 600, 8, '[]', true);

-- Inline Activities for Brave Little Robot
INSERT INTO inline_activities (id, chapter_id, type, after_paragraph_index, content, xp_reward, vocabulary_words) VALUES
-- Chapter 1 activities
('66666666-0006-0001-0001-000000000001', '55555555-0002-0003-0001-000000000001', 'word_translation', 0,
'{"word": "robot", "correctAnswer": "robot", "options": ["robot", "insan", "hayvan"]}', 5, ARRAY['11111111-0004-0001-0001-000000000010']),
('66666666-0006-0001-0001-000000000002', '55555555-0002-0003-0001-000000000001', 'true_false', 0,
'{"statement": "Beep was the smallest robot in the factory.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0006-0001-0001-000000000003', '55555555-0002-0003-0001-000000000001', 'word_translation', 0,
'{"word": "factory", "correctAnswer": "fabrika", "options": ["fabrika", "okul", "hastane"]}', 5, ARRAY['11111111-0004-0001-0001-000000000011']),
-- Chapter 2 activities
('66666666-0006-0002-0001-000000000001', '55555555-0002-0003-0001-000000000002', 'word_translation', 0,
'{"word": "problem", "correctAnswer": "sorun", "options": ["sorun", "cozum", "oyun"]}', 5, ARRAY['11111111-0004-0001-0001-000000000012']),
('66666666-0006-0002-0001-000000000002', '55555555-0002-0003-0001-000000000002', 'true_false', 0,
'{"statement": "The power station was broken.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0006-0002-0001-000000000003', '55555555-0002-0003-0001-000000000002', 'find_words', 0,
'{"instruction": "Why couldn''t the big robots help?", "options": ["Too big", "Too tired", "Scared", "Broken"], "correctAnswers": ["Too big"]}', 5, ARRAY[]::TEXT[]),
-- Chapter 3 activities
('66666666-0006-0003-0001-000000000001', '55555555-0002-0003-0001-000000000003', 'word_translation', 0,
'{"word": "hero", "correctAnswer": "kahraman", "options": ["kahraman", "kotu", "korkak"]}', 5, ARRAY['11111111-0004-0001-0001-000000000013']),
('66666666-0006-0003-0001-000000000002', '55555555-0002-0003-0001-000000000003', 'true_false', 0,
'{"statement": "The city celebrated Beep as a hero.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0006-0003-0001-000000000003', '55555555-0002-0003-0001-000000000003', 'word_translation', 0,
'{"word": "brave", "correctAnswer": "cesur", "options": ["cesur", "korkak", "yalniz"]}', 5, ARRAY['11111111-0004-0001-0001-000000000014']);

-- Content Blocks for Brave Little Robot - Chapter 1
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000003-0001-0001-0001-000000000001', '55555555-0002-0003-0001-000000000001', 1, 'text',
'In the middle of Robot City, there was a big factory where robots were made. The factory was busy all day and all night, building robots of all shapes and sizes.', NULL, NULL, NULL),
('cb000003-0001-0001-0001-000000000002', '55555555-0002-0003-0001-000000000001', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1565098772267-60af42b81ef2?w=600', 'A futuristic robot factory', NULL),
('cb000003-0001-0001-0001-000000000003', '55555555-0002-0003-0001-000000000001', 3, 'activity',
NULL, NULL, NULL, '66666666-0006-0001-0001-000000000001'),
('cb000003-0001-0001-0001-000000000004', '55555555-0002-0003-0001-000000000001', 4, 'text',
'One day, a very special robot was created. His name was Beep, and he was the smallest robot in the whole factory. He was only as tall as a water bottle!', NULL, NULL, NULL),
('cb000003-0001-0001-0001-000000000005', '55555555-0002-0003-0001-000000000001', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1546776310-eef45dd6d63c?w=600', 'A cute small robot', NULL),
('cb000003-0001-0001-0001-000000000006', '55555555-0002-0003-0001-000000000001', 6, 'activity',
NULL, NULL, NULL, '66666666-0006-0001-0001-000000000002'),
('cb000003-0001-0001-0001-000000000007', '55555555-0002-0003-0001-000000000001', 7, 'text',
'"You are too small," said the big robots. "What can you do?" Beep felt sad. He wanted to help, but nobody gave him a chance.', NULL, NULL, NULL),
('cb000003-0001-0001-0001-000000000008', '55555555-0002-0003-0001-000000000001', 8, 'activity',
NULL, NULL, NULL, '66666666-0006-0001-0001-000000000003'),
('cb000003-0001-0001-0001-000000000009', '55555555-0002-0003-0001-000000000001', 9, 'text',
'But Beep never gave up. He practiced and practiced. He learned to climb, to jump, and to squeeze through tiny spaces. "One day," he thought, "I will show everyone what I can do!"', NULL, NULL, NULL);

-- Content Blocks for Brave Little Robot - Chapter 2
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000003-0002-0001-0001-000000000001', '55555555-0002-0003-0001-000000000002', 1, 'text',
'One dark night, something terrible happened. The city''s power station broke down! All the lights went out. All the machines stopped working. Robot City was in trouble!', NULL, NULL, NULL),
('cb000003-0002-0001-0001-000000000002', '55555555-0002-0003-0001-000000000002', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1579547621113-e4bb2a19bdd6?w=600', 'A city in darkness', NULL),
('cb000003-0002-0001-0001-000000000003', '55555555-0002-0003-0001-000000000002', 3, 'activity',
NULL, NULL, NULL, '66666666-0006-0002-0001-000000000001'),
('cb000003-0002-0001-0001-000000000004', '55555555-0002-0003-0001-000000000002', 4, 'text',
'"We need to fix the power station!" shouted the Mayor. But there was a big problem. The broken part was deep inside a tiny tunnel. None of the big robots could fit inside!', NULL, NULL, NULL),
('cb000003-0002-0001-0001-000000000005', '55555555-0002-0003-0001-000000000002', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600', 'A narrow tunnel entrance', NULL),
('cb000003-0002-0001-0001-000000000006', '55555555-0002-0003-0001-000000000002', 6, 'activity',
NULL, NULL, NULL, '66666666-0006-0002-0001-000000000002'),
('cb000003-0002-0001-0001-000000000007', '55555555-0002-0003-0001-000000000002', 7, 'text',
'"I can help!" said a small voice. Everyone turned around. It was Beep! The big robots laughed. "You? You are too small!"', NULL, NULL, NULL),
('cb000003-0002-0001-0001-000000000008', '55555555-0002-0003-0001-000000000002', 8, 'activity',
NULL, NULL, NULL, '66666666-0006-0002-0001-000000000003'),
('cb000003-0002-0001-0001-000000000009', '55555555-0002-0003-0001-000000000002', 9, 'text',
'But the Mayor said, "Wait. Being small might be exactly what we need!" She gave Beep the repair tools and said, "We believe in you, Beep. Go save our city!"', NULL, NULL, NULL);

-- Content Blocks for Brave Little Robot - Chapter 3
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000003-0003-0001-0001-000000000001', '55555555-0002-0003-0001-000000000003', 1, 'text',
'Beep squeezed into the tiny tunnel. It was dark and scary, but Beep kept going. He crawled through pipes and climbed over wires until he found the broken part.', NULL, NULL, NULL),
('cb000003-0003-0001-0001-000000000002', '55555555-0002-0003-0001-000000000003', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600', 'Inside machinery with wires', NULL),
('cb000003-0003-0001-0001-000000000003', '55555555-0002-0003-0001-000000000003', 3, 'activity',
NULL, NULL, NULL, '66666666-0006-0003-0001-000000000001'),
('cb000003-0003-0001-0001-000000000004', '55555555-0002-0003-0001-000000000003', 4, 'text',
'Beep worked quickly. He connected the wires, tightened the bolts, and pressed the restart button. Suddenly, the lights came back on all over the city! Beep had done it!', NULL, NULL, NULL),
('cb000003-0003-0001-0001-000000000005', '55555555-0002-0003-0001-000000000003', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=600', 'A city with lights on at night', NULL),
('cb000003-0003-0001-0001-000000000006', '55555555-0002-0003-0001-000000000003', 6, 'activity',
NULL, NULL, NULL, '66666666-0006-0003-0001-000000000002'),
('cb000003-0003-0001-0001-000000000007', '55555555-0002-0003-0001-000000000003', 7, 'text',
'When Beep came out of the tunnel, everyone was cheering! "Beep! Beep! Beep!" they shouted. The Mayor gave Beep a golden medal. "You are a hero!" she said.', NULL, NULL, NULL),
('cb000003-0003-0001-0001-000000000008', '55555555-0002-0003-0001-000000000003', 8, 'image',
NULL, 'https://images.unsplash.com/photo-1533227268428-f9ed0900fb3b?w=600', 'A celebration with colorful lights', NULL),
('cb000003-0003-0001-0001-000000000009', '55555555-0002-0003-0001-000000000003', 9, 'activity',
NULL, NULL, NULL, '66666666-0006-0003-0001-000000000003'),
('cb000003-0003-0001-0001-000000000010', '55555555-0002-0003-0001-000000000003', 10, 'text',
'From that day on, nobody laughed at Beep anymore. They learned an important lesson: it does not matter how big or small you are. What matters is how brave and kind you are inside!', NULL, NULL, NULL);

-- =============================================
-- BOOK 4: Ocean Explorers (A1 - Elementary)
-- =============================================
INSERT INTO books (id, title, slug, description, cover_url, level, genre, age_group, estimated_minutes, word_count, chapter_count, status, metadata, published_at) VALUES
('44444444-0002-0004-0001-000000000001', 'Ocean Explorers', 'ocean-explorers', 'Dive deep into the ocean with Maya and her dolphin friend Splash! Discover colorful coral reefs, mysterious caves, and amazing sea creatures.', 'https://images.unsplash.com/photo-1551244072-5d12893278ab?w=400', 'A1', 'Fiction', 'elementary', 25, 1400, 3, 'published', '{"author": "Sea Stories", "year": 2024}', NOW());

-- Chapters for Ocean Explorers
INSERT INTO chapters (id, book_id, title, order_index, content, word_count, estimated_minutes, vocabulary, use_content_blocks) VALUES
('55555555-0002-0004-0001-000000000001', '44444444-0002-0004-0001-000000000001', 'Meeting Splash', 1, NULL, 450, 6, '[]', true),
('55555555-0002-0004-0001-000000000002', '44444444-0002-0004-0001-000000000001', 'The Coral Kingdom', 2, NULL, 450, 6, '[]', true),
('55555555-0002-0004-0001-000000000003', '44444444-0002-0004-0001-000000000001', 'The Lost Treasure', 3, NULL, 500, 7, '[]', true);

-- Inline Activities for Ocean Explorers
INSERT INTO inline_activities (id, chapter_id, type, after_paragraph_index, content, xp_reward, vocabulary_words) VALUES
-- Chapter 1 activities
('66666666-0007-0001-0001-000000000001', '55555555-0002-0004-0001-000000000001', 'word_translation', 0,
'{"word": "ocean", "correctAnswer": "okyanus", "options": ["okyanus", "gol", "nehir"]}', 5, ARRAY['11111111-0004-0001-0001-000000000015']),
('66666666-0007-0001-0001-000000000002', '55555555-0002-0004-0001-000000000001', 'true_false', 0,
'{"statement": "Maya lived near the ocean.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0007-0001-0001-000000000003', '55555555-0002-0004-0001-000000000001', 'word_translation', 0,
'{"word": "dolphin", "correctAnswer": "yunus", "options": ["yunus", "kopekbaligi", "balina"]}', 5, ARRAY['11111111-0002-0001-0001-000000000004']),
-- Chapter 2 activities
('66666666-0007-0002-0001-000000000001', '55555555-0002-0004-0001-000000000002', 'word_translation', 0,
'{"word": "coral", "correctAnswer": "mercan", "options": ["mercan", "tas", "kum"]}', 5, ARRAY['11111111-0004-0001-0001-000000000016']),
('66666666-0007-0002-0001-000000000002', '55555555-0002-0004-0001-000000000002', 'find_words', 0,
'{"instruction": "Which sea creatures did Maya see?", "options": ["Fish", "Turtle", "Octopus", "Bird"], "correctAnswers": ["Fish", "Turtle", "Octopus"]}', 5, ARRAY[]::TEXT[]),
('66666666-0007-0002-0001-000000000003', '55555555-0002-0004-0001-000000000002', 'true_false', 0,
'{"statement": "The coral reef was very colorful.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
-- Chapter 3 activities
('66666666-0007-0003-0001-000000000001', '55555555-0002-0004-0001-000000000003', 'word_translation', 0,
'{"word": "treasure", "correctAnswer": "hazine", "options": ["hazine", "canta", "kum"]}', 5, ARRAY['11111111-0004-0001-0001-000000000017']),
('66666666-0007-0003-0001-000000000002', '55555555-0002-0004-0001-000000000003', 'true_false', 0,
'{"statement": "Maya found an old treasure chest.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0007-0003-0001-000000000003', '55555555-0002-0004-0001-000000000003', 'word_translation', 0,
'{"word": "friend", "correctAnswer": "arkadas", "options": ["arkadas", "dusman", "yabanc"]}', 5, ARRAY['11111111-0001-0001-0001-000000000007']);

-- Content Blocks for Ocean Explorers - Chapter 1
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000004-0001-0001-0001-000000000001', '55555555-0002-0004-0001-000000000001', 1, 'text',
'Maya loved the ocean more than anything in the world. She lived in a small house by the beach and spent every day playing in the waves.', NULL, NULL, NULL),
('cb000004-0001-0001-0001-000000000002', '55555555-0002-0004-0001-000000000001', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600', 'A beautiful beach with blue ocean', NULL),
('cb000004-0001-0001-0001-000000000003', '55555555-0002-0004-0001-000000000001', 3, 'activity',
NULL, NULL, NULL, '66666666-0007-0001-0001-000000000001'),
('cb000004-0001-0001-0001-000000000004', '55555555-0002-0004-0001-000000000001', 4, 'text',
'One sunny morning, Maya saw something splashing in the water. She swam closer and could not believe her eyes - it was a baby dolphin!', NULL, NULL, NULL),
('cb000004-0001-0001-0001-000000000005', '55555555-0002-0004-0001-000000000001', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1570481662006-a3a1374699e8?w=600', 'A friendly dolphin swimming', NULL),
('cb000004-0001-0001-0001-000000000006', '55555555-0002-0004-0001-000000000001', 6, 'activity',
NULL, NULL, NULL, '66666666-0007-0001-0001-000000000002'),
('cb000004-0001-0001-0001-000000000007', '55555555-0002-0004-0001-000000000001', 7, 'text',
'The dolphin clicked and whistled happily. "Hello, little one!" said Maya. "I will call you Splash!" The dolphin seemed to like the name.', NULL, NULL, NULL),
('cb000004-0001-0001-0001-000000000008', '55555555-0002-0004-0001-000000000001', 8, 'activity',
NULL, NULL, NULL, '66666666-0007-0001-0001-000000000003'),
('cb000004-0001-0001-0001-000000000009', '55555555-0002-0004-0001-000000000001', 9, 'text',
'From that day on, Maya and Splash became best friends. They swam together every day, and Splash showed Maya all the secret places in the ocean.', NULL, NULL, NULL);

-- Content Blocks for Ocean Explorers - Chapter 2
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000004-0002-0001-0001-000000000001', '55555555-0002-0004-0001-000000000002', 1, 'text',
'"Follow me!" clicked Splash one day. Maya put on her goggles and dove under the water. Splash led her to the most amazing place she had ever seen.', NULL, NULL, NULL),
('cb000004-0002-0001-0001-000000000002', '55555555-0002-0004-0001-000000000002', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1546026423-cc4642628d2b?w=600', 'A beautiful underwater coral reef', NULL),
('cb000004-0002-0001-0001-000000000003', '55555555-0002-0004-0001-000000000002', 3, 'activity',
NULL, NULL, NULL, '66666666-0007-0002-0001-000000000001'),
('cb000004-0002-0001-0001-000000000004', '55555555-0002-0004-0001-000000000002', 4, 'text',
'It was a coral reef! There were corals of every color - pink, purple, orange, and blue. Beautiful fish swam all around them.', NULL, NULL, NULL),
('cb000004-0002-0001-0001-000000000005', '55555555-0002-0004-0001-000000000002', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=600', 'Colorful tropical fish', NULL),
('cb000004-0002-0001-0001-000000000006', '55555555-0002-0004-0001-000000000002', 6, 'activity',
NULL, NULL, NULL, '66666666-0007-0002-0001-000000000002'),
('cb000004-0002-0001-0001-000000000007', '55555555-0002-0004-0001-000000000002', 7, 'text',
'Maya saw a green turtle swimming slowly by. An octopus waved at her with all eight arms. A school of tiny silver fish sparkled like glitter.', NULL, NULL, NULL),
('cb000004-0002-0001-0001-000000000008', '55555555-0002-0004-0001-000000000002', 8, 'image',
NULL, 'https://images.unsplash.com/photo-1437622368342-7a3d73a34c8f?w=600', 'A sea turtle swimming', NULL),
('cb000004-0002-0001-0001-000000000009', '55555555-0002-0004-0001-000000000002', 9, 'activity',
NULL, NULL, NULL, '66666666-0007-0002-0001-000000000003');

-- Content Blocks for Ocean Explorers - Chapter 3
INSERT INTO content_blocks (id, chapter_id, order_index, type, text, image_url, caption, activity_id) VALUES
('cb000004-0003-0001-0001-000000000001', '55555555-0002-0004-0001-000000000003', 1, 'text',
'Behind the coral reef, there was a dark cave. Splash clicked excitedly and swam inside. Maya followed her friend into the mysterious cave.', NULL, NULL, NULL),
('cb000004-0003-0001-0001-000000000002', '55555555-0002-0004-0001-000000000003', 2, 'image',
NULL, 'https://images.unsplash.com/photo-1544552866-d3ed42536cfd?w=600', 'An underwater cave', NULL),
('cb000004-0003-0001-0001-000000000003', '55555555-0002-0004-0001-000000000003', 3, 'activity',
NULL, NULL, NULL, '66666666-0007-0003-0001-000000000001'),
('cb000004-0003-0001-0001-000000000004', '55555555-0002-0004-0001-000000000003', 4, 'text',
'Inside the cave, Maya saw something shining on the sandy floor. It was an old treasure chest covered in seashells and seaweed!', NULL, NULL, NULL),
('cb000004-0003-0001-0001-000000000005', '55555555-0002-0004-0001-000000000003', 5, 'image',
NULL, 'https://images.unsplash.com/photo-1516117172878-fd2c41f4a759?w=600', 'An old treasure chest', NULL),
('cb000004-0003-0001-0001-000000000006', '55555555-0002-0004-0001-000000000003', 6, 'activity',
NULL, NULL, NULL, '66666666-0007-0003-0001-000000000002'),
('cb000004-0003-0001-0001-000000000007', '55555555-0002-0004-0001-000000000003', 7, 'text',
'Maya opened the chest carefully. Inside, there were no gold coins or jewels. Instead, there was something even better - a beautiful pearl necklace and an old map!', NULL, NULL, NULL),
('cb000004-0003-0001-0001-000000000008', '55555555-0002-0004-0001-000000000003', 8, 'image',
NULL, 'https://images.unsplash.com/photo-1515377905703-c4788e51af15?w=600', 'A beautiful pearl', NULL),
('cb000004-0003-0001-0001-000000000009', '55555555-0002-0004-0001-000000000003', 9, 'activity',
NULL, NULL, NULL, '66666666-0007-0003-0001-000000000003'),
('cb000004-0003-0001-0001-000000000010', '55555555-0002-0004-0001-000000000003', 10, 'text',
'"More adventures await us, Splash!" Maya said happily. She hugged her dolphin friend. Together, they would explore every corner of the ocean!', NULL, NULL, NULL);

-- =============================================
-- READING PROGRESS (for new content block books)
-- =============================================

-- ACTIVE USER: Reading "The Magic Garden", completed chapter 1
INSERT INTO reading_progress (id, user_id, book_id, chapter_id, current_page, is_completed, completion_percentage, total_reading_time, completed_chapter_ids, started_at, updated_at) VALUES
('99999999-0001-0001-0001-000000000001', '88888888-0001-0001-0001-000000000002', '44444444-0002-0001-0001-000000000001',
'55555555-0002-0001-0001-000000000002', 1, false, 33.33, 600,
ARRAY['55555555-0002-0001-0001-000000000001']::UUID[], NOW() - INTERVAL '3 days', NOW() - INTERVAL '1 day');

-- ADVANCED USER: Completed "The Magic Garden"
INSERT INTO reading_progress (id, user_id, book_id, chapter_id, current_page, is_completed, completion_percentage, total_reading_time, completed_chapter_ids, started_at, completed_at, updated_at) VALUES
('99999999-0001-0001-0001-000000000002', '88888888-0001-0001-0001-000000000003', '44444444-0002-0001-0001-000000000001',
'55555555-0002-0001-0001-000000000003', 1, true, 100.0, 1200,
ARRAY['55555555-0002-0001-0001-000000000001', '55555555-0002-0001-0001-000000000002', '55555555-0002-0001-0001-000000000003']::UUID[],
NOW() - INTERVAL '7 days', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days');

-- ADVANCED USER: Reading "Space Adventure"
INSERT INTO reading_progress (id, user_id, book_id, chapter_id, current_page, is_completed, completion_percentage, total_reading_time, completed_chapter_ids, started_at, updated_at) VALUES
('99999999-0001-0001-0001-000000000003', '88888888-0001-0001-0001-000000000003', '44444444-0002-0002-0001-000000000001',
'55555555-0002-0002-0001-000000000002', 1, false, 33.33, 900,
ARRAY['55555555-0002-0002-0001-000000000001']::UUID[], NOW() - INTERVAL '3 days', NOW());

-- =============================================
-- ASSIGNMENTS (Teacher assignments for new books)
-- =============================================
INSERT INTO assignments (id, teacher_id, class_id, type, title, description, content_config, start_date, due_date, created_at) VALUES
-- Active assignment: Read Magic Garden
('cccccccc-0001-0001-0001-000000000001', '88888888-0001-0001-0001-000000000004', '77777777-0001-0001-0001-000000000001', 'book', 'Read The Magic Garden', 'Read and complete all activities for The Magic Garden.', '{"bookId": "44444444-0002-0001-0001-000000000001", "chapterIds": ["55555555-0002-0001-0001-000000000001", "55555555-0002-0001-0001-000000000002", "55555555-0002-0001-0001-000000000003"]}', NOW() - INTERVAL '3 days', NOW() + INTERVAL '4 days', NOW() - INTERVAL '3 days'),

-- Upcoming assignment: Vocabulary practice
('cccccccc-0001-0001-0001-000000000002', '88888888-0001-0001-0001-000000000004', '77777777-0001-0001-0001-000000000001', 'vocabulary', 'A1 Vocabulary Practice', 'Master the first 10 A1 level vocabulary words.', '{"wordListId": null}', NOW() + INTERVAL '2 days', NOW() + INTERVAL '9 days', NOW()),

-- Overdue assignment
('cccccccc-0001-0001-0001-000000000003', '88888888-0001-0001-0001-000000000004', '77777777-0001-0001-0001-000000000001', 'book', 'The Magic Garden - Chapter 1', 'Complete the first chapter of The Magic Garden.', '{"bookId": "44444444-0002-0001-0001-000000000001", "chapterIds": ["55555555-0002-0001-0001-000000000001"]}', NOW() - INTERVAL '14 days', NOW() - INTERVAL '7 days', NOW() - INTERVAL '14 days');

-- =============================================
-- ASSIGNMENT STUDENTS (Student progress on assignments)
-- =============================================
INSERT INTO assignment_students (id, assignment_id, student_id, status, progress, score, started_at, completed_at) VALUES
-- Assignment 1 (Active): Mixed progress
('dddddddd-0001-0001-0001-000000000001', 'cccccccc-0001-0001-0001-000000000001', '88888888-0001-0001-0001-000000000001', 'pending', 0, NULL, NULL, NULL),
('dddddddd-0001-0001-0001-000000000002', 'cccccccc-0001-0001-0001-000000000001', '88888888-0001-0001-0001-000000000002', 'in_progress', 50, NULL, NOW() - INTERVAL '2 days', NULL),
('dddddddd-0001-0001-0001-000000000003', 'cccccccc-0001-0001-0001-000000000001', '88888888-0001-0001-0001-000000000003', 'completed', 100, 95.5, NOW() - INTERVAL '2 days', NOW() - INTERVAL '1 day'),

-- Assignment 2 (Upcoming): All pending
('dddddddd-0001-0001-0001-000000000004', 'cccccccc-0001-0001-0001-000000000002', '88888888-0001-0001-0001-000000000001', 'pending', 0, NULL, NULL, NULL),
('dddddddd-0001-0001-0001-000000000005', 'cccccccc-0001-0001-0001-000000000002', '88888888-0001-0001-0001-000000000002', 'pending', 0, NULL, NULL, NULL),
('dddddddd-0001-0001-0001-000000000006', 'cccccccc-0001-0001-0001-000000000002', '88888888-0001-0001-0001-000000000003', 'pending', 0, NULL, NULL, NULL),

-- Assignment 3 (Overdue): Some completed, some overdue
('dddddddd-0001-0001-0001-000000000007', 'cccccccc-0001-0001-0001-000000000003', '88888888-0001-0001-0001-000000000001', 'overdue', 30, NULL, NOW() - INTERVAL '12 days', NULL),
('dddddddd-0001-0001-0001-000000000008', 'cccccccc-0001-0001-0001-000000000003', '88888888-0001-0001-0001-000000000002', 'completed', 100, 88.0, NOW() - INTERVAL '13 days', NOW() - INTERVAL '8 days'),
('dddddddd-0001-0001-0001-000000000009', 'cccccccc-0001-0001-0001-000000000003', '88888888-0001-0001-0001-000000000003', 'completed', 100, 100.0, NOW() - INTERVAL '13 days', NOW() - INTERVAL '10 days');
