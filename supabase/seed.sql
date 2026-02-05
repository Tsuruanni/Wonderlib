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

-- =============================================
-- CONTENT BLOCKS AUDIO DATA (Generated by Fal AI TTS)
-- =============================================

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb2e/gGqAR9tAy-hDbxg2eWzT0_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 12937,
  word_timings = '[{"word":"One","startIndex":0,"endIndex":3,"startMs":0,"endMs":240},{"word":"sunny","startIndex":4,"endIndex":9,"startMs":306,"endMs":636},{"word":"morning,","startIndex":10,"endIndex":18,"startMs":696,"endMs":1436},{"word":"a","startIndex":19,"endIndex":20,"startMs":1516,"endMs":1595},{"word":"little","startIndex":21,"endIndex":27,"startMs":1630,"endMs":1834},{"word":"girl","startIndex":28,"endIndex":32,"startMs":1914,"endMs":2234},{"word":"named","startIndex":33,"endIndex":38,"startMs":2300,"endMs":2630},{"word":"Lily","startIndex":39,"endIndex":43,"startMs":2726,"endMs":3110},{"word":"walked","startIndex":44,"endIndex":50,"startMs":3190,"endMs":3670},{"word":"into","startIndex":51,"endIndex":55,"startMs":3734,"endMs":3989},{"word":"her","startIndex":56,"endIndex":59,"startMs":4030,"endMs":4150},{"word":"grandmother''s","startIndex":60,"endIndex":73,"startMs":4202,"endMs":4946},{"word":"backyard.","startIndex":74,"endIndex":83,"startMs":5026,"endMs":5746},{"word":"She","startIndex":84,"endIndex":87,"startMs":6045,"endMs":6946},{"word":"loved","startIndex":88,"endIndex":93,"startMs":7039,"endMs":7504},{"word":"playing","startIndex":94,"endIndex":101,"startMs":7553,"endMs":7904},{"word":"there","startIndex":102,"endIndex":107,"startMs":7957,"endMs":8222},{"word":"because","startIndex":108,"endIndex":115,"startMs":8322,"endMs":9022},{"word":"it","startIndex":116,"endIndex":118,"startMs":9075,"endMs":9181},{"word":"was","startIndex":119,"endIndex":122,"startMs":9221,"endMs":9341},{"word":"full","startIndex":123,"endIndex":127,"startMs":9421,"endMs":9741},{"word":"of","startIndex":128,"endIndex":130,"startMs":9821,"endMs":9981},{"word":"beautiful","startIndex":131,"endIndex":140,"startMs":10045,"endMs":10620},{"word":"flowers","startIndex":141,"endIndex":148,"startMs":10690,"endMs":11181},{"word":"and","startIndex":149,"endIndex":152,"startMs":11300,"endMs":11661},{"word":"tall","startIndex":153,"endIndex":157,"startMs":11773,"endMs":12221},{"word":"trees.","startIndex":158,"endIndex":164,"startMs":12327,"endMs":12937}]'
WHERE id = 'cb000001-0001-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb2e/gGqAR9tAy-hDbxg2eWzT0_output.mp3',
  audio_start_ms = 13282,
  audio_end_ms = 28441,
  word_timings = '[{"word":"Today,","startIndex":0,"endIndex":6,"startMs":13282,"endMs":14692},{"word":"something","startIndex":7,"endIndex":16,"startMs":14804,"endMs":15812},{"word":"was","startIndex":17,"endIndex":20,"startMs":15872,"endMs":16052},{"word":"different.","startIndex":21,"endIndex":31,"startMs":16100,"endMs":16612},{"word":"Behind","startIndex":32,"endIndex":38,"startMs":16829,"endMs":18131},{"word":"the","startIndex":39,"endIndex":42,"startMs":18171,"endMs":18291},{"word":"rose","startIndex":43,"endIndex":47,"startMs":18355,"endMs":18611},{"word":"bushes,","startIndex":48,"endIndex":55,"startMs":18691,"endMs":19651},{"word":"Lily","startIndex":56,"endIndex":60,"startMs":19731,"endMs":20051},{"word":"saw","startIndex":61,"endIndex":64,"startMs":20111,"endMs":20291},{"word":"something","startIndex":65,"endIndex":74,"startMs":20339,"endMs":20771},{"word":"she","startIndex":75,"endIndex":78,"startMs":20831,"endMs":21011},{"word":"had","startIndex":79,"endIndex":82,"startMs":21071,"endMs":21251},{"word":"never","startIndex":83,"endIndex":88,"startMs":21317,"endMs":21647},{"word":"noticed","startIndex":89,"endIndex":96,"startMs":21707,"endMs":22127},{"word":"before","startIndex":97,"endIndex":103,"startMs":22195,"endMs":22603},{"word":"-","startIndex":104,"endIndex":105,"startMs":23163,"endMs":23723},{"word":"a","startIndex":106,"endIndex":107,"startMs":23763,"endMs":23803},{"word":"small","startIndex":108,"endIndex":113,"startMs":23896,"endMs":24361},{"word":"wooden","startIndex":114,"endIndex":120,"startMs":24441,"endMs":24921},{"word":"gate","startIndex":121,"endIndex":125,"startMs":25033,"endMs":25481},{"word":"covered","startIndex":126,"endIndex":133,"startMs":25581,"endMs":26281},{"word":"in","startIndex":134,"endIndex":136,"startMs":26361,"endMs":26521},{"word":"green","startIndex":137,"endIndex":142,"startMs":26601,"endMs":27001},{"word":"vines.","startIndex":143,"endIndex":149,"startMs":27121,"endMs":28441}]'
WHERE id = 'cb000001-0001-0001-0001-000000000003';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb2e/gGqAR9tAy-hDbxg2eWzT0_output.mp3',
  audio_start_ms = 29261,
  audio_end_ms = 44949,
  word_timings = '[{"word":"How","startIndex":1,"endIndex":4,"startMs":29261,"endMs":29321},{"word":"strange!","startIndex":5,"endIndex":13,"startMs":29431,"endMs":30361},{"word":"Lily","startIndex":14,"endIndex":18,"startMs":30521,"endMs":31161},{"word":"whispered.","startIndex":19,"endIndex":29,"startMs":31209,"endMs":32201},{"word":"I","startIndex":30,"endIndex":31,"startMs":32481,"endMs":32761},{"word":"have","startIndex":32,"endIndex":36,"startMs":32793,"endMs":32921},{"word":"never","startIndex":37,"endIndex":42,"startMs":32974,"endMs":33239},{"word":"seen","startIndex":43,"endIndex":47,"startMs":33303,"endMs":33559},{"word":"this","startIndex":48,"endIndex":52,"startMs":33591,"endMs":33719},{"word":"gate","startIndex":53,"endIndex":57,"startMs":33799,"endMs":34119},{"word":"before.","startIndex":58,"endIndex":65,"startMs":34187,"endMs":34675},{"word":"She","startIndex":66,"endIndex":69,"startMs":35035,"endMs":36115},{"word":"touched","startIndex":70,"endIndex":77,"startMs":36175,"endMs":36595},{"word":"the","startIndex":78,"endIndex":81,"startMs":36635,"endMs":36755},{"word":"old","startIndex":82,"endIndex":85,"startMs":36815,"endMs":36995},{"word":"wood","startIndex":86,"endIndex":90,"startMs":37059,"endMs":37315},{"word":"carefully.","startIndex":91,"endIndex":101,"startMs":37387,"endMs":38115},{"word":"The","startIndex":102,"endIndex":105,"startMs":38375,"endMs":39155},{"word":"gate","startIndex":106,"endIndex":110,"startMs":39235,"endMs":39555},{"word":"was","startIndex":111,"endIndex":114,"startMs":39615,"endMs":39795},{"word":"warm,","startIndex":115,"endIndex":120,"startMs":39923,"endMs":40995},{"word":"like","startIndex":121,"endIndex":125,"startMs":41043,"endMs":41235},{"word":"it","startIndex":126,"endIndex":128,"startMs":41261,"endMs":41313},{"word":"had","startIndex":129,"endIndex":132,"startMs":41353,"endMs":41473},{"word":"been","startIndex":133,"endIndex":137,"startMs":41505,"endMs":41633},{"word":"sitting","startIndex":138,"endIndex":145,"startMs":41703,"endMs":42193},{"word":"in","startIndex":146,"endIndex":148,"startMs":42219,"endMs":42271},{"word":"the","startIndex":149,"endIndex":152,"startMs":42311,"endMs":42431},{"word":"sunshine","startIndex":153,"endIndex":161,"startMs":42511,"endMs":43151},{"word":"for","startIndex":162,"endIndex":165,"startMs":43211,"endMs":43391},{"word":"hours.","startIndex":166,"endIndex":172,"startMs":43524,"endMs":44949}]'
WHERE id = 'cb000001-0001-0001-0001-000000000005';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb2e/gGqAR9tAy-hDbxg2eWzT0_output.mp3',
  audio_start_ms = 45852,
  audio_end_ms = 59371,
  word_timings = '[{"word":"Lily","startIndex":0,"endIndex":4,"startMs":45852,"endMs":45948},{"word":"pushed","startIndex":5,"endIndex":11,"startMs":46016,"endMs":46424},{"word":"the","startIndex":12,"endIndex":15,"startMs":46444,"endMs":46504},{"word":"gate","startIndex":16,"endIndex":20,"startMs":46568,"endMs":46824},{"word":"gently.","startIndex":21,"endIndex":28,"startMs":46904,"endMs":47464},{"word":"To","startIndex":29,"endIndex":31,"startMs":47837,"endMs":48583},{"word":"her","startIndex":32,"endIndex":35,"startMs":48643,"endMs":48823},{"word":"surprise,","startIndex":36,"endIndex":45,"startMs":48894,"endMs":49942},{"word":"it","startIndex":46,"endIndex":48,"startMs":49995,"endMs":50101},{"word":"opened","startIndex":49,"endIndex":55,"startMs":50169,"endMs":50577},{"word":"with","startIndex":56,"endIndex":60,"startMs":50609,"endMs":50737},{"word":"a","startIndex":61,"endIndex":62,"startMs":50777,"endMs":50817},{"word":"soft","startIndex":63,"endIndex":67,"startMs":50929,"endMs":51377},{"word":"creak.","startIndex":68,"endIndex":74,"startMs":51537,"endMs":52177},{"word":"On","startIndex":75,"endIndex":77,"startMs":52603,"endMs":53455},{"word":"the","startIndex":78,"endIndex":81,"startMs":53495,"endMs":53615},{"word":"other","startIndex":82,"endIndex":87,"startMs":53655,"endMs":53855},{"word":"side,","startIndex":88,"endIndex":93,"startMs":53951,"endMs":54895},{"word":"she","startIndex":94,"endIndex":97,"startMs":54955,"endMs":55135},{"word":"saw","startIndex":98,"endIndex":101,"startMs":55235,"endMs":55535},{"word":"the","startIndex":102,"endIndex":105,"startMs":55575,"endMs":55695},{"word":"most","startIndex":106,"endIndex":110,"startMs":55759,"endMs":56015},{"word":"beautiful","startIndex":111,"endIndex":120,"startMs":56087,"endMs":56735},{"word":"garden","startIndex":121,"endIndex":127,"startMs":56803,"endMs":57211},{"word":"she","startIndex":128,"endIndex":131,"startMs":57351,"endMs":57771},{"word":"had","startIndex":132,"endIndex":135,"startMs":57831,"endMs":58011},{"word":"ever","startIndex":136,"endIndex":140,"startMs":58123,"endMs":58571},{"word":"seen!","startIndex":141,"endIndex":146,"startMs":58715,"endMs":59371}]'
WHERE id = 'cb000001-0001-0001-0001-000000000008';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3a/H1j4Z-S-RAF-mj5Id3zn0_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 16720,
  word_timings = '[{"word":"The","startIndex":0,"endIndex":3,"startMs":0,"endMs":159},{"word":"garden","startIndex":4,"endIndex":10,"startMs":250,"endMs":796},{"word":"was","startIndex":11,"endIndex":14,"startMs":896,"endMs":1196},{"word":"magical!","startIndex":15,"endIndex":23,"startMs":1315,"endMs":2796},{"word":"Flowers","startIndex":24,"endIndex":31,"startMs":2875,"endMs":3436},{"word":"of","startIndex":32,"endIndex":34,"startMs":3489,"endMs":3594},{"word":"every","startIndex":35,"endIndex":40,"startMs":3687,"endMs":4153},{"word":"color","startIndex":41,"endIndex":46,"startMs":4233,"endMs":4632},{"word":"grew","startIndex":47,"endIndex":51,"startMs":4712,"endMs":5032},{"word":"everywhere","startIndex":52,"endIndex":62,"startMs":5104,"endMs":5824},{"word":"-","startIndex":63,"endIndex":64,"startMs":6184,"endMs":6544},{"word":"red","startIndex":65,"endIndex":68,"startMs":6624,"endMs":6864},{"word":"roses,","startIndex":69,"endIndex":75,"startMs":6970,"endMs":7821},{"word":"yellow","startIndex":76,"endIndex":82,"startMs":7877,"endMs":8219},{"word":"sunflowers,","startIndex":83,"endIndex":94,"startMs":8320,"endMs":9335},{"word":"purple","startIndex":95,"endIndex":101,"startMs":9403,"endMs":9811},{"word":"violets,","startIndex":102,"endIndex":110,"startMs":9892,"endMs":10531},{"word":"and","startIndex":111,"endIndex":114,"startMs":10631,"endMs":10931},{"word":"white","startIndex":115,"endIndex":120,"startMs":10985,"endMs":11249},{"word":"daisies.","startIndex":121,"endIndex":129,"startMs":11329,"endMs":12127},{"word":"But","startIndex":130,"endIndex":133,"startMs":12387,"endMs":13168},{"word":"these","startIndex":134,"endIndex":139,"startMs":13247,"endMs":13647},{"word":"were","startIndex":140,"endIndex":144,"startMs":13743,"endMs":14127},{"word":"not","startIndex":145,"endIndex":148,"startMs":14207,"endMs":14447},{"word":"ordinary","startIndex":149,"endIndex":157,"startMs":14535,"endMs":15239},{"word":"flowers.","startIndex":158,"endIndex":166,"startMs":15319,"endMs":16720}]'
WHERE id = 'cb000001-0002-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3a/H1j4Z-S-RAF-mj5Id3zn0_output.mp3',
  audio_start_ms = 17793,
  audio_end_ms = 28816,
  word_timings = '[{"word":"Hello,","startIndex":1,"endIndex":7,"startMs":17793,"endMs":18118},{"word":"little","startIndex":8,"endIndex":14,"startMs":18140,"endMs":18272},{"word":"girl!","startIndex":15,"endIndex":20,"startMs":18352,"endMs":18832},{"word":"said","startIndex":21,"endIndex":25,"startMs":18960,"endMs":19471},{"word":"a","startIndex":26,"endIndex":27,"startMs":19511,"endMs":19551},{"word":"red","startIndex":28,"endIndex":31,"startMs":19612,"endMs":19791},{"word":"rose","startIndex":32,"endIndex":36,"startMs":19871,"endMs":20191},{"word":"in","startIndex":37,"endIndex":39,"startMs":20244,"endMs":20351},{"word":"a","startIndex":40,"endIndex":41,"startMs":20430,"endMs":20511},{"word":"sweet","startIndex":42,"endIndex":47,"startMs":20577,"endMs":20906},{"word":"voice.","startIndex":48,"endIndex":54,"startMs":20999,"endMs":21624},{"word":"Lily","startIndex":55,"endIndex":59,"startMs":21864,"endMs":22824},{"word":"jumped","startIndex":60,"endIndex":66,"startMs":22869,"endMs":23139},{"word":"back","startIndex":67,"endIndex":71,"startMs":23187,"endMs":23379},{"word":"in","startIndex":72,"endIndex":74,"startMs":23432,"endMs":23538},{"word":"surprise.","startIndex":75,"endIndex":84,"startMs":23609,"endMs":24257},{"word":"Did","startIndex":85,"endIndex":88,"startMs":24557,"endMs":25457},{"word":"you...","startIndex":89,"endIndex":95,"startMs":25497,"endMs":26496},{"word":"did","startIndex":96,"endIndex":99,"startMs":26536,"endMs":26656},{"word":"you","startIndex":100,"endIndex":103,"startMs":26696,"endMs":26816},{"word":"just","startIndex":104,"endIndex":108,"startMs":26864,"endMs":27056},{"word":"talk?","startIndex":109,"endIndex":114,"startMs":27152,"endMs":27616},{"word":"she","startIndex":115,"endIndex":118,"startMs":27776,"endMs":28256},{"word":"asked.","startIndex":119,"endIndex":125,"startMs":28336,"endMs":28816}]'
WHERE id = 'cb000001-0002-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3a/H1j4Z-S-RAF-mj5Id3zn0_output.mp3',
  audio_start_ms = 30041,
  audio_end_ms = 44958,
  word_timings = '[{"word":"Of","startIndex":1,"endIndex":3,"startMs":30041,"endMs":30093},{"word":"course","startIndex":4,"endIndex":10,"startMs":30161,"endMs":30569},{"word":"we","startIndex":11,"endIndex":13,"startMs":30649,"endMs":30809},{"word":"can","startIndex":14,"endIndex":17,"startMs":30869,"endMs":31049},{"word":"talk!","startIndex":18,"endIndex":23,"startMs":31145,"endMs":31889},{"word":"laughed","startIndex":24,"endIndex":31,"startMs":31935,"endMs":32250},{"word":"the","startIndex":32,"endIndex":35,"startMs":32290,"endMs":32409},{"word":"rose.","startIndex":36,"endIndex":41,"startMs":32489,"endMs":33169},{"word":"We","startIndex":42,"endIndex":44,"startMs":33290,"endMs":33530},{"word":"can","startIndex":45,"endIndex":48,"startMs":33570,"endMs":33690},{"word":"also","startIndex":49,"endIndex":53,"startMs":33769,"endMs":34089},{"word":"sing!","startIndex":54,"endIndex":59,"startMs":34202,"endMs":34730},{"word":"Then","startIndex":60,"endIndex":64,"startMs":34986,"endMs":36010},{"word":"all","startIndex":65,"endIndex":68,"startMs":36089,"endMs":36330},{"word":"the","startIndex":69,"endIndex":72,"startMs":36370,"endMs":36489},{"word":"flowers","startIndex":73,"endIndex":80,"startMs":36550,"endMs":36969},{"word":"started","startIndex":81,"endIndex":88,"startMs":37029,"endMs":37449},{"word":"singing","startIndex":89,"endIndex":96,"startMs":37499,"endMs":37849},{"word":"a","startIndex":97,"endIndex":98,"startMs":37929,"endMs":38010},{"word":"beautiful","startIndex":99,"endIndex":108,"startMs":38081,"endMs":38730},{"word":"song","startIndex":109,"endIndex":113,"startMs":38809,"endMs":39129},{"word":"together.","startIndex":114,"endIndex":123,"startMs":39192,"endMs":39767},{"word":"The","startIndex":124,"endIndex":127,"startMs":39988,"endMs":40647},{"word":"sunflowers","startIndex":128,"endIndex":138,"startMs":40727,"endMs":41367},{"word":"hummed","startIndex":139,"endIndex":145,"startMs":41446,"endMs":41846},{"word":"the","startIndex":146,"endIndex":149,"startMs":41866,"endMs":41925},{"word":"melody","startIndex":150,"endIndex":156,"startMs":42006,"endMs":42486},{"word":"while","startIndex":157,"endIndex":162,"startMs":42592,"endMs":43122},{"word":"the","startIndex":163,"endIndex":166,"startMs":43162,"endMs":43282},{"word":"daisies","startIndex":167,"endIndex":174,"startMs":43361,"endMs":43922},{"word":"added","startIndex":175,"endIndex":180,"startMs":43988,"endMs":44318},{"word":"harmony.","startIndex":181,"endIndex":189,"startMs":44388,"endMs":44958}]'
WHERE id = 'cb000001-0002-0001-0001-000000000006';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3a/H1j4Z-S-RAF-mj5Id3zn0_output.mp3',
  audio_start_ms = 46091,
  audio_end_ms = 57732,
  word_timings = '[{"word":"Lily","startIndex":0,"endIndex":4,"startMs":46091,"endMs":46795},{"word":"listened","startIndex":5,"endIndex":13,"startMs":46858,"endMs":47353},{"word":"with","startIndex":14,"endIndex":18,"startMs":47385,"endMs":47513},{"word":"wonder.","startIndex":19,"endIndex":26,"startMs":47593,"endMs":48154},{"word":"She","startIndex":27,"endIndex":30,"startMs":48373,"endMs":49034},{"word":"had","startIndex":31,"endIndex":34,"startMs":49074,"endMs":49193},{"word":"never","startIndex":35,"endIndex":40,"startMs":49260,"endMs":49589},{"word":"heard","startIndex":41,"endIndex":46,"startMs":49656,"endMs":49986},{"word":"anything","startIndex":47,"endIndex":55,"startMs":50056,"endMs":50625},{"word":"so","startIndex":56,"endIndex":58,"startMs":50757,"endMs":51023},{"word":"beautiful","startIndex":59,"endIndex":68,"startMs":51087,"endMs":51663},{"word":"in","startIndex":69,"endIndex":71,"startMs":51823,"endMs":52143},{"word":"her","startIndex":72,"endIndex":75,"startMs":52203,"endMs":52383},{"word":"whole","startIndex":76,"endIndex":81,"startMs":52449,"endMs":52779},{"word":"life.","startIndex":82,"endIndex":87,"startMs":52875,"endMs":53859},{"word":"The","startIndex":88,"endIndex":91,"startMs":54009,"endMs":54459},{"word":"flowers","startIndex":92,"endIndex":99,"startMs":54529,"endMs":55019},{"word":"danced","startIndex":100,"endIndex":106,"startMs":55099,"endMs":55579},{"word":"in","startIndex":107,"endIndex":109,"startMs":55605,"endMs":55657},{"word":"the","startIndex":110,"endIndex":113,"startMs":55677,"endMs":55737},{"word":"gentle","startIndex":114,"endIndex":120,"startMs":55805,"endMs":56213},{"word":"breeze","startIndex":121,"endIndex":127,"startMs":56293,"endMs":56773},{"word":"as","startIndex":128,"endIndex":130,"startMs":56826,"endMs":56932},{"word":"they","startIndex":131,"endIndex":135,"startMs":56964,"endMs":57092},{"word":"sang.","startIndex":136,"endIndex":141,"startMs":57204,"endMs":57732}]'
WHERE id = 'cb000001-0002-0001-0001-000000000008';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3c/DZ5e3MW_JREX2pIvPM6Cv_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 14469,
  word_timings = '[{"word":"After","startIndex":0,"endIndex":5,"startMs":0,"endMs":320},{"word":"the","startIndex":6,"endIndex":9,"startMs":360,"endMs":480},{"word":"song","startIndex":10,"endIndex":14,"startMs":560,"endMs":880},{"word":"ended,","startIndex":15,"endIndex":21,"startMs":960,"endMs":1760},{"word":"Lily","startIndex":22,"endIndex":26,"startMs":1824,"endMs":2080},{"word":"noticed","startIndex":27,"endIndex":34,"startMs":2150,"endMs":2640},{"word":"something","startIndex":35,"endIndex":44,"startMs":2680,"endMs":3040},{"word":"flying","startIndex":45,"endIndex":51,"startMs":3120,"endMs":3600},{"word":"toward","startIndex":52,"endIndex":58,"startMs":3680,"endMs":4160},{"word":"her.","startIndex":59,"endIndex":63,"startMs":4220,"endMs":4480},{"word":"It","startIndex":64,"endIndex":66,"startMs":4853,"endMs":5599},{"word":"was","startIndex":67,"endIndex":70,"startMs":5659,"endMs":5839},{"word":"the","startIndex":71,"endIndex":74,"startMs":5879,"endMs":5999},{"word":"most","startIndex":75,"endIndex":79,"startMs":6079,"endMs":6399},{"word":"beautiful","startIndex":80,"endIndex":89,"startMs":6479,"endMs":7199},{"word":"butterfly","startIndex":90,"endIndex":99,"startMs":7271,"endMs":7919},{"word":"she","startIndex":100,"endIndex":103,"startMs":8079,"endMs":8559},{"word":"had","startIndex":104,"endIndex":107,"startMs":8599,"endMs":8719},{"word":"ever","startIndex":108,"endIndex":112,"startMs":8815,"endMs":9199},{"word":"seen.","startIndex":113,"endIndex":118,"startMs":9311,"endMs":10399},{"word":"Its","startIndex":119,"endIndex":122,"startMs":10559,"endMs":11039},{"word":"wings","startIndex":123,"endIndex":128,"startMs":11119,"endMs":11519},{"word":"were","startIndex":129,"endIndex":133,"startMs":11551,"endMs":11679},{"word":"golden","startIndex":134,"endIndex":140,"startMs":11770,"endMs":12316},{"word":"and","startIndex":141,"endIndex":144,"startMs":12416,"endMs":12716},{"word":"sparkled","startIndex":145,"endIndex":153,"startMs":12822,"endMs":13511},{"word":"in","startIndex":154,"endIndex":156,"startMs":13564,"endMs":13670},{"word":"the","startIndex":157,"endIndex":160,"startMs":13690,"endMs":13750},{"word":"sunlight.","startIndex":161,"endIndex":170,"startMs":13821,"endMs":14469}]'
WHERE id = 'cb000001-0003-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3c/DZ5e3MW_JREX2pIvPM6Cv_output.mp3',
  audio_start_ms = 15987,
  audio_end_ms = 29013,
  word_timings = '[{"word":"I","startIndex":1,"endIndex":2,"startMs":15987,"endMs":16067},{"word":"am","startIndex":3,"endIndex":5,"startMs":16147,"endMs":16307},{"word":"the","startIndex":6,"endIndex":9,"startMs":16347,"endMs":16467},{"word":"Wish","startIndex":10,"endIndex":14,"startMs":16547,"endMs":16867},{"word":"Butterfly,","startIndex":15,"endIndex":25,"startMs":16955,"endMs":17827},{"word":"it","startIndex":26,"endIndex":28,"startMs":18067,"endMs":18547},{"word":"said,","startIndex":29,"endIndex":34,"startMs":18611,"endMs":19187},{"word":"landing","startIndex":35,"endIndex":42,"startMs":19237,"endMs":19587},{"word":"softly","startIndex":43,"endIndex":49,"startMs":19678,"endMs":20224},{"word":"on","startIndex":50,"endIndex":52,"startMs":20250,"endMs":20302},{"word":"Lily''s","startIndex":53,"endIndex":59,"startMs":20366,"endMs":20702},{"word":"finger.","startIndex":60,"endIndex":67,"startMs":20759,"endMs":21181},{"word":"I","startIndex":68,"endIndex":69,"startMs":21821,"endMs":22461},{"word":"can","startIndex":70,"endIndex":73,"startMs":22521,"endMs":22701},{"word":"grant","startIndex":74,"endIndex":79,"startMs":22767,"endMs":23097},{"word":"one","startIndex":80,"endIndex":83,"startMs":23197,"endMs":23497},{"word":"wish","startIndex":84,"endIndex":88,"startMs":23577,"endMs":23897},{"word":"to","startIndex":89,"endIndex":91,"startMs":24083,"endMs":24455},{"word":"anyone","startIndex":92,"endIndex":98,"startMs":24535,"endMs":25015},{"word":"who","startIndex":99,"endIndex":102,"startMs":25055,"endMs":25175},{"word":"finds","startIndex":103,"endIndex":108,"startMs":25255,"endMs":25655},{"word":"the","startIndex":109,"endIndex":112,"startMs":25695,"endMs":25815},{"word":"magic","startIndex":113,"endIndex":118,"startMs":25895,"endMs":26295},{"word":"garden.","startIndex":119,"endIndex":126,"startMs":26375,"endMs":26935},{"word":"What","startIndex":127,"endIndex":131,"startMs":27159,"endMs":28055},{"word":"do","startIndex":132,"endIndex":134,"startMs":28081,"endMs":28133},{"word":"you","startIndex":135,"endIndex":138,"startMs":28173,"endMs":28293},{"word":"wish","startIndex":139,"endIndex":143,"startMs":28357,"endMs":28613},{"word":"for?","startIndex":144,"endIndex":148,"startMs":28693,"endMs":29013}]'
WHERE id = 'cb000001-0003-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3c/DZ5e3MW_JREX2pIvPM6Cv_output.mp3',
  audio_start_ms = 30405,
  audio_end_ms = 45640,
  word_timings = '[{"word":"Lily","startIndex":0,"endIndex":4,"startMs":30405,"endMs":30533},{"word":"thought","startIndex":5,"endIndex":12,"startMs":30573,"endMs":30853},{"word":"carefully.","startIndex":13,"endIndex":23,"startMs":30933,"endMs":31733},{"word":"She","startIndex":24,"endIndex":27,"startMs":31993,"endMs":32773},{"word":"could","startIndex":28,"endIndex":33,"startMs":32813,"endMs":33013},{"word":"wish","startIndex":34,"endIndex":38,"startMs":33061,"endMs":33253},{"word":"for","startIndex":39,"endIndex":42,"startMs":33293,"endMs":33413},{"word":"toys,","startIndex":43,"endIndex":48,"startMs":33557,"endMs":34533},{"word":"or","startIndex":49,"endIndex":51,"startMs":34586,"endMs":34692},{"word":"candy,","startIndex":52,"endIndex":58,"startMs":34798,"endMs":35808},{"word":"or","startIndex":59,"endIndex":61,"startMs":35861,"endMs":35967},{"word":"anything!","startIndex":62,"endIndex":71,"startMs":36038,"endMs":36686},{"word":"But","startIndex":72,"endIndex":75,"startMs":36946,"endMs":37726},{"word":"then","startIndex":76,"endIndex":80,"startMs":37806,"endMs":38126},{"word":"she","startIndex":81,"endIndex":84,"startMs":38206,"endMs":38446},{"word":"smiled.","startIndex":85,"endIndex":92,"startMs":38537,"endMs":39843},{"word":"I","startIndex":93,"endIndex":94,"startMs":40223,"endMs":40603},{"word":"wish","startIndex":95,"endIndex":99,"startMs":40651,"endMs":40843},{"word":"to","startIndex":100,"endIndex":102,"startMs":40896,"endMs":41002},{"word":"come","startIndex":103,"endIndex":107,"startMs":41034,"endMs":41162},{"word":"back","startIndex":108,"endIndex":112,"startMs":41226,"endMs":41482},{"word":"and","startIndex":113,"endIndex":116,"startMs":41582,"endMs":41882},{"word":"visit","startIndex":117,"endIndex":122,"startMs":41935,"endMs":42200},{"word":"my","startIndex":123,"endIndex":125,"startMs":42280,"endMs":42440},{"word":"new","startIndex":126,"endIndex":129,"startMs":42480,"endMs":42600},{"word":"friends","startIndex":130,"endIndex":137,"startMs":42670,"endMs":43160},{"word":"whenever","startIndex":138,"endIndex":146,"startMs":43240,"endMs":43880},{"word":"I","startIndex":147,"endIndex":148,"startMs":44000,"endMs":44120},{"word":"want,","startIndex":149,"endIndex":154,"startMs":44200,"endMs":44920},{"word":"she","startIndex":155,"endIndex":158,"startMs":45000,"endMs":45240},{"word":"said.","startIndex":159,"endIndex":164,"startMs":45304,"endMs":45640}]'
WHERE id = 'cb000001-0003-0001-0001-000000000006';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3c/DZ5e3MW_JREX2pIvPM6Cv_output.mp3',
  audio_start_ms = 46890,
  audio_end_ms = 63778,
  word_timings = '[{"word":"The","startIndex":0,"endIndex":3,"startMs":46890,"endMs":46920},{"word":"butterfly''s","startIndex":4,"endIndex":15,"startMs":46976,"endMs":47560},{"word":"wings","startIndex":16,"endIndex":21,"startMs":47640,"endMs":48040},{"word":"glowed","startIndex":22,"endIndex":28,"startMs":48120,"endMs":48600},{"word":"brightly.","startIndex":29,"endIndex":38,"startMs":48662,"endMs":49318},{"word":"Your","startIndex":39,"endIndex":43,"startMs":49558,"endMs":50518},{"word":"wish","startIndex":44,"endIndex":48,"startMs":50598,"endMs":50918},{"word":"is","startIndex":49,"endIndex":51,"startMs":51024,"endMs":51236},{"word":"granted!","startIndex":52,"endIndex":60,"startMs":51316,"endMs":52036},{"word":"it","startIndex":61,"endIndex":63,"startMs":52249,"endMs":52675},{"word":"said.","startIndex":64,"endIndex":69,"startMs":52755,"endMs":53155},{"word":"The","startIndex":70,"endIndex":73,"startMs":53355,"endMs":53955},{"word":"magic","startIndex":74,"endIndex":79,"startMs":54035,"endMs":54435},{"word":"garden","startIndex":80,"endIndex":86,"startMs":54503,"endMs":54911},{"word":"will","startIndex":87,"endIndex":91,"startMs":55039,"endMs":55551},{"word":"always","startIndex":92,"endIndex":98,"startMs":55619,"endMs":56027},{"word":"welcome","startIndex":99,"endIndex":106,"startMs":56097,"endMs":56587},{"word":"you.","startIndex":107,"endIndex":111,"startMs":56647,"endMs":56907},{"word":"And","startIndex":112,"endIndex":115,"startMs":57227,"endMs":58187},{"word":"from","startIndex":116,"endIndex":120,"startMs":58219,"endMs":58347},{"word":"that","startIndex":121,"endIndex":125,"startMs":58411,"endMs":58667},{"word":"day","startIndex":126,"endIndex":129,"startMs":58707,"endMs":58827},{"word":"on,","startIndex":130,"endIndex":133,"startMs":58933,"endMs":59545},{"word":"Lily","startIndex":134,"endIndex":138,"startMs":59609,"endMs":59865},{"word":"visited","startIndex":139,"endIndex":146,"startMs":59925,"endMs":60345},{"word":"her","startIndex":147,"endIndex":150,"startMs":60385,"endMs":60505},{"word":"flower","startIndex":151,"endIndex":157,"startMs":60562,"endMs":60904},{"word":"friends","startIndex":158,"endIndex":165,"startMs":60984,"endMs":61544},{"word":"every","startIndex":166,"endIndex":171,"startMs":61664,"endMs":62264},{"word":"single","startIndex":172,"endIndex":178,"startMs":62366,"endMs":62978},{"word":"day.","startIndex":179,"endIndex":183,"startMs":63158,"endMs":63778}]'
WHERE id = 'cb000001-0003-0001-0001-000000000009';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3e/o6Dqscf0-bGVaPJSadx58_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 13346,
  word_timings = '[{"word":"Max","startIndex":0,"endIndex":3,"startMs":0,"endMs":399},{"word":"was","startIndex":4,"endIndex":7,"startMs":459,"endMs":639},{"word":"the","startIndex":8,"endIndex":11,"startMs":659,"endMs":719},{"word":"youngest","startIndex":12,"endIndex":20,"startMs":781,"endMs":1277},{"word":"astronaut","startIndex":21,"endIndex":30,"startMs":1349,"endMs":1997},{"word":"in","startIndex":31,"endIndex":33,"startMs":2077,"endMs":2237},{"word":"the","startIndex":34,"endIndex":37,"startMs":2277,"endMs":2397},{"word":"world.","startIndex":38,"endIndex":44,"startMs":2477,"endMs":2957},{"word":"He","startIndex":45,"endIndex":47,"startMs":3197,"endMs":3676},{"word":"was","startIndex":48,"endIndex":51,"startMs":3716,"endMs":3836},{"word":"only","startIndex":52,"endIndex":56,"startMs":3933,"endMs":4317},{"word":"ten","startIndex":57,"endIndex":60,"startMs":4436,"endMs":4797},{"word":"years","startIndex":61,"endIndex":66,"startMs":4863,"endMs":5193},{"word":"old!","startIndex":67,"endIndex":71,"startMs":5333,"endMs":5833},{"word":"Today","startIndex":72,"endIndex":77,"startMs":6113,"endMs":7513},{"word":"was","startIndex":78,"endIndex":81,"startMs":7653,"endMs":8073},{"word":"a","startIndex":82,"endIndex":83,"startMs":8113,"endMs":8153},{"word":"very","startIndex":84,"endIndex":88,"startMs":8249,"endMs":8633},{"word":"special","startIndex":89,"endIndex":96,"startMs":8703,"endMs":9193},{"word":"day","startIndex":97,"endIndex":100,"startMs":9293,"endMs":9593},{"word":"-","startIndex":101,"endIndex":102,"startMs":9993,"endMs":10393},{"word":"his","startIndex":103,"endIndex":106,"startMs":10453,"endMs":10633},{"word":"first","startIndex":107,"endIndex":112,"startMs":10726,"endMs":11191},{"word":"mission","startIndex":113,"endIndex":120,"startMs":11251,"endMs":11671},{"word":"to","startIndex":121,"endIndex":123,"startMs":11804,"endMs":12070},{"word":"space.","startIndex":124,"endIndex":130,"startMs":12176,"endMs":13346}]'
WHERE id = 'cb000002-0001-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3e/o6Dqscf0-bGVaPJSadx58_output.mp3',
  audio_start_ms = 14085,
  audio_end_ms = 25893,
  word_timings = '[{"word":"Are","startIndex":1,"endIndex":4,"startMs":14085,"endMs":14145},{"word":"you","startIndex":5,"endIndex":8,"startMs":14165,"endMs":14225},{"word":"ready,","startIndex":9,"endIndex":15,"startMs":14278,"endMs":14623},{"word":"Max?","startIndex":16,"endIndex":20,"startMs":14742,"endMs":15263},{"word":"asked","startIndex":21,"endIndex":26,"startMs":15395,"endMs":16061},{"word":"Captain","startIndex":27,"endIndex":34,"startMs":16120,"endMs":16541},{"word":"Luna.","startIndex":35,"endIndex":40,"startMs":16621,"endMs":17581},{"word":"Yes!","startIndex":41,"endIndex":45,"startMs":17741,"endMs":18381},{"word":"Max","startIndex":46,"endIndex":49,"startMs":18561,"endMs":19101},{"word":"shouted","startIndex":50,"endIndex":57,"startMs":19160,"endMs":19581},{"word":"excitedly.","startIndex":58,"endIndex":68,"startMs":19651,"endMs":20381},{"word":"He","startIndex":69,"endIndex":71,"startMs":20701,"endMs":21341},{"word":"put","startIndex":72,"endIndex":75,"startMs":21381,"endMs":21500},{"word":"on","startIndex":76,"endIndex":78,"startMs":21554,"endMs":21660},{"word":"his","startIndex":79,"endIndex":82,"startMs":21700,"endMs":21820},{"word":"space","startIndex":83,"endIndex":88,"startMs":21886,"endMs":22216},{"word":"helmet","startIndex":89,"endIndex":95,"startMs":22273,"endMs":22615},{"word":"and","startIndex":96,"endIndex":99,"startMs":22755,"endMs":23175},{"word":"climbed","startIndex":100,"endIndex":107,"startMs":23245,"endMs":23735},{"word":"into","startIndex":108,"endIndex":112,"startMs":23783,"endMs":23975},{"word":"the","startIndex":113,"endIndex":116,"startMs":24015,"endMs":24135},{"word":"shiny","startIndex":117,"endIndex":122,"startMs":24228,"endMs":24693},{"word":"silver","startIndex":123,"endIndex":129,"startMs":24773,"endMs":25253},{"word":"rocket.","startIndex":130,"endIndex":137,"startMs":25333,"endMs":25893}]'
WHERE id = 'cb000002-0001-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3e/o6Dqscf0-bGVaPJSadx58_output.mp3',
  audio_start_ms = 27197,
  audio_end_ms = 51394,
  word_timings = '[{"word":"10...","startIndex":1,"endIndex":6,"startMs":27197,"endMs":27488},{"word":"9...","startIndex":7,"endIndex":11,"startMs":28208,"endMs":29486},{"word":"8...","startIndex":12,"endIndex":16,"startMs":29806,"endMs":30766},{"word":"7...","startIndex":17,"endIndex":21,"startMs":30926,"endMs":32046},{"word":"6...","startIndex":22,"endIndex":26,"startMs":32446,"endMs":33726},{"word":"5...","startIndex":27,"endIndex":31,"startMs":33806,"endMs":35005},{"word":"4...","startIndex":32,"endIndex":36,"startMs":35045,"endMs":36285},{"word":"3...","startIndex":37,"endIndex":41,"startMs":36365,"endMs":37564},{"word":"2...","startIndex":42,"endIndex":46,"startMs":37684,"endMs":39082},{"word":"1...","startIndex":47,"endIndex":51,"startMs":39482,"endMs":40682},{"word":"BLAST","startIndex":52,"endIndex":57,"startMs":40762,"endMs":41162},{"word":"OFF!","startIndex":58,"endIndex":62,"startMs":41262,"endMs":41722},{"word":"The","startIndex":63,"endIndex":66,"startMs":42022,"endMs":42922},{"word":"rocket","startIndex":67,"endIndex":73,"startMs":42990,"endMs":43397},{"word":"shot","startIndex":74,"endIndex":78,"startMs":43510,"endMs":43958},{"word":"up","startIndex":79,"endIndex":81,"startMs":44038,"endMs":44197},{"word":"into","startIndex":82,"endIndex":86,"startMs":44261,"endMs":44517},{"word":"the","startIndex":87,"endIndex":90,"startMs":44557,"endMs":44678},{"word":"sky","startIndex":91,"endIndex":94,"startMs":44797,"endMs":45157},{"word":"like","startIndex":95,"endIndex":99,"startMs":45254,"endMs":45638},{"word":"a","startIndex":100,"endIndex":101,"startMs":45718,"endMs":45797},{"word":"giant","startIndex":102,"endIndex":107,"startMs":45891,"endMs":46355},{"word":"firework.","startIndex":108,"endIndex":117,"startMs":46435,"endMs":47155},{"word":"Max","startIndex":118,"endIndex":121,"startMs":47495,"endMs":48515},{"word":"felt","startIndex":122,"endIndex":126,"startMs":48563,"endMs":48755},{"word":"himself","startIndex":127,"endIndex":134,"startMs":48815,"endMs":49235},{"word":"being","startIndex":135,"endIndex":140,"startMs":49275,"endMs":49475},{"word":"pushed","startIndex":141,"endIndex":147,"startMs":49532,"endMs":49874},{"word":"back","startIndex":148,"endIndex":152,"startMs":49954,"endMs":50274},{"word":"into","startIndex":153,"endIndex":157,"startMs":50354,"endMs":50674},{"word":"his","startIndex":158,"endIndex":161,"startMs":50734,"endMs":50914},{"word":"seat.","startIndex":162,"endIndex":167,"startMs":50978,"endMs":51394}]'
WHERE id = 'cb000002-0001-0001-0001-000000000007';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb3e/o6Dqscf0-bGVaPJSadx58_output.mp3',
  audio_start_ms = 52945,
  audio_end_ms = 67368,
  word_timings = '[{"word":"Soon,","startIndex":0,"endIndex":5,"startMs":52945,"endMs":53153},{"word":"the","startIndex":6,"endIndex":9,"startMs":53253,"endMs":53553},{"word":"sky","startIndex":10,"endIndex":13,"startMs":53653,"endMs":53953},{"word":"turned","startIndex":14,"endIndex":20,"startMs":54021,"endMs":54429},{"word":"from","startIndex":21,"endIndex":25,"startMs":54477,"endMs":54669},{"word":"blue","startIndex":26,"endIndex":30,"startMs":54765,"endMs":55149},{"word":"to","startIndex":31,"endIndex":33,"startMs":55255,"endMs":55467},{"word":"black.","startIndex":34,"endIndex":40,"startMs":55560,"endMs":56105},{"word":"Max","startIndex":41,"endIndex":44,"startMs":56445,"endMs":57465},{"word":"looked","startIndex":45,"endIndex":51,"startMs":57499,"endMs":57703},{"word":"out","startIndex":52,"endIndex":55,"startMs":57763,"endMs":57943},{"word":"the","startIndex":56,"endIndex":59,"startMs":57963,"endMs":58023},{"word":"window","startIndex":60,"endIndex":66,"startMs":58091,"endMs":58499},{"word":"and","startIndex":67,"endIndex":70,"startMs":58599,"endMs":58899},{"word":"saw","startIndex":71,"endIndex":74,"startMs":58979,"endMs":59219},{"word":"millions","startIndex":75,"endIndex":83,"startMs":59307,"endMs":60011},{"word":"of","startIndex":84,"endIndex":86,"startMs":60064,"endMs":60170},{"word":"twinkling","startIndex":87,"endIndex":96,"startMs":60250,"endMs":60810},{"word":"stars.","startIndex":97,"endIndex":103,"startMs":60930,"endMs":61690},{"word":"Wow!","startIndex":104,"endIndex":108,"startMs":62110,"endMs":63530},{"word":"he","startIndex":109,"endIndex":111,"startMs":63743,"endMs":64169},{"word":"whispered.","startIndex":112,"endIndex":122,"startMs":64225,"endMs":64889},{"word":"Space","startIndex":123,"endIndex":128,"startMs":65049,"endMs":65849},{"word":"is","startIndex":129,"endIndex":131,"startMs":65929,"endMs":66089},{"word":"so","startIndex":132,"endIndex":134,"startMs":66222,"endMs":66488},{"word":"beautiful!","startIndex":135,"endIndex":145,"startMs":66561,"endMs":67368}]'
WHERE id = 'cb000002-0001-0001-0001-000000000010';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb40/yMTRQZYDvP9f-ZjF70aha_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 12213,
  word_timings = '[{"word":"After","startIndex":0,"endIndex":5,"startMs":0,"endMs":320},{"word":"flying","startIndex":6,"endIndex":12,"startMs":400,"endMs":880},{"word":"for","startIndex":13,"endIndex":16,"startMs":920,"endMs":1040},{"word":"three","startIndex":17,"endIndex":22,"startMs":1106,"endMs":1436},{"word":"days,","startIndex":23,"endIndex":28,"startMs":1532,"endMs":2316},{"word":"Max","startIndex":29,"endIndex":32,"startMs":2436,"endMs":2796},{"word":"finally","startIndex":33,"endIndex":40,"startMs":2876,"endMs":3436},{"word":"saw","startIndex":41,"endIndex":44,"startMs":3535,"endMs":3836},{"word":"it","startIndex":45,"endIndex":47,"startMs":3941,"endMs":4154},{"word":"-","startIndex":48,"endIndex":49,"startMs":4514,"endMs":4874},{"word":"Mars,","startIndex":50,"endIndex":55,"startMs":5034,"endMs":5994},{"word":"the","startIndex":56,"endIndex":59,"startMs":6074,"endMs":6314},{"word":"Red","startIndex":60,"endIndex":63,"startMs":6433,"endMs":6794},{"word":"Planet!","startIndex":64,"endIndex":71,"startMs":6874,"endMs":7434},{"word":"It","startIndex":72,"endIndex":74,"startMs":7780,"endMs":8472},{"word":"looked","startIndex":75,"endIndex":81,"startMs":8540,"endMs":8948},{"word":"like","startIndex":82,"endIndex":86,"startMs":8980,"endMs":9108},{"word":"a","startIndex":87,"endIndex":88,"startMs":9148,"endMs":9188},{"word":"giant","startIndex":89,"endIndex":94,"startMs":9281,"endMs":9746},{"word":"orange","startIndex":95,"endIndex":101,"startMs":9814,"endMs":10222},{"word":"ball","startIndex":102,"endIndex":106,"startMs":10318,"endMs":10702},{"word":"floating","startIndex":107,"endIndex":115,"startMs":10790,"endMs":11494},{"word":"in","startIndex":116,"endIndex":118,"startMs":11547,"endMs":11653},{"word":"space.","startIndex":119,"endIndex":125,"startMs":11733,"endMs":12213}]'
WHERE id = 'cb000002-0002-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb40/yMTRQZYDvP9f-ZjF70aha_output.mp3',
  audio_start_ms = 13622,
  audio_end_ms = 26955,
  word_timings = '[{"word":"The","startIndex":0,"endIndex":3,"startMs":13622,"endMs":13652},{"word":"rocket","startIndex":4,"endIndex":10,"startMs":13720,"endMs":14128},{"word":"landed","startIndex":11,"endIndex":17,"startMs":14185,"endMs":14527},{"word":"gently","startIndex":18,"endIndex":24,"startMs":14618,"endMs":15164},{"word":"on","startIndex":25,"endIndex":27,"startMs":15270,"endMs":15482},{"word":"the","startIndex":28,"endIndex":31,"startMs":15522,"endMs":15642},{"word":"red","startIndex":32,"endIndex":35,"startMs":15742,"endMs":16042},{"word":"surface.","startIndex":36,"endIndex":44,"startMs":16132,"endMs":16842},{"word":"Max","startIndex":45,"endIndex":48,"startMs":17142,"endMs":18042},{"word":"put","startIndex":49,"endIndex":52,"startMs":18082,"endMs":18202},{"word":"on","startIndex":53,"endIndex":55,"startMs":18282,"endMs":18442},{"word":"his","startIndex":56,"endIndex":59,"startMs":18482,"endMs":18602},{"word":"special","startIndex":60,"endIndex":67,"startMs":18662,"endMs":19082},{"word":"boots","startIndex":68,"endIndex":73,"startMs":19162,"endMs":19562},{"word":"and","startIndex":74,"endIndex":77,"startMs":19682,"endMs":20042},{"word":"stepped","startIndex":78,"endIndex":85,"startMs":20102,"endMs":20522},{"word":"outside.","startIndex":86,"endIndex":94,"startMs":20612,"endMs":21322},{"word":"The","startIndex":95,"endIndex":98,"startMs":21622,"endMs":22522},{"word":"ground","startIndex":99,"endIndex":105,"startMs":22590,"endMs":22998},{"word":"was","startIndex":106,"endIndex":109,"startMs":23058,"endMs":23238},{"word":"covered","startIndex":110,"endIndex":117,"startMs":23288,"endMs":23638},{"word":"in","startIndex":118,"endIndex":120,"startMs":23691,"endMs":23797},{"word":"red","startIndex":121,"endIndex":124,"startMs":23897,"endMs":24197},{"word":"rocks","startIndex":125,"endIndex":130,"startMs":24290,"endMs":24755},{"word":"and","startIndex":131,"endIndex":134,"startMs":24875,"endMs":25235},{"word":"red","startIndex":135,"endIndex":138,"startMs":25335,"endMs":25635},{"word":"dust.","startIndex":139,"endIndex":144,"startMs":25747,"endMs":26955}]'
WHERE id = 'cb000002-0002-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb40/yMTRQZYDvP9f-ZjF70aha_output.mp3',
  audio_start_ms = 27810,
  audio_end_ms = 40821,
  word_timings = '[{"word":"Look","startIndex":1,"endIndex":5,"startMs":27810,"endMs":27874},{"word":"at","startIndex":6,"endIndex":8,"startMs":27927,"endMs":28033},{"word":"those","startIndex":9,"endIndex":14,"startMs":28086,"endMs":28351},{"word":"mountains!","startIndex":15,"endIndex":25,"startMs":28439,"endMs":29391},{"word":"Max","startIndex":26,"endIndex":29,"startMs":29711,"endMs":30671},{"word":"pointed","startIndex":30,"endIndex":37,"startMs":30741,"endMs":31231},{"word":"at","startIndex":38,"endIndex":40,"startMs":31337,"endMs":31549},{"word":"the","startIndex":41,"endIndex":44,"startMs":31589,"endMs":31709},{"word":"huge","startIndex":45,"endIndex":49,"startMs":31805,"endMs":32189},{"word":"red","startIndex":50,"endIndex":53,"startMs":32269,"endMs":32509},{"word":"mountains","startIndex":54,"endIndex":63,"startMs":32565,"endMs":33069},{"word":"in","startIndex":64,"endIndex":66,"startMs":33122,"endMs":33228},{"word":"the","startIndex":67,"endIndex":70,"startMs":33248,"endMs":33308},{"word":"distance.","startIndex":71,"endIndex":80,"startMs":33379,"endMs":34107},{"word":"They","startIndex":81,"endIndex":85,"startMs":34299,"endMs":35067},{"word":"were","startIndex":86,"endIndex":90,"startMs":35099,"endMs":35227},{"word":"much","startIndex":91,"endIndex":95,"startMs":35323,"endMs":35707},{"word":"bigger","startIndex":96,"endIndex":102,"startMs":35764,"endMs":36106},{"word":"than","startIndex":103,"endIndex":107,"startMs":36202,"endMs":36586},{"word":"any","startIndex":108,"endIndex":111,"startMs":36666,"endMs":36906},{"word":"mountains","startIndex":112,"endIndex":121,"startMs":36962,"endMs":37466},{"word":"on","startIndex":122,"endIndex":124,"startMs":37519,"endMs":37625},{"word":"Earth.","startIndex":125,"endIndex":131,"startMs":37691,"endMs":38101},{"word":"Mars","startIndex":132,"endIndex":136,"startMs":38357,"endMs":39381},{"word":"was","startIndex":137,"endIndex":140,"startMs":39501,"endMs":39861},{"word":"amazing!","startIndex":141,"endIndex":149,"startMs":39971,"endMs":40821}]'
WHERE id = 'cb000002-0002-0001-0001-000000000007';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb40/yMTRQZYDvP9f-ZjF70aha_output.mp3',
  audio_start_ms = 42670,
  audio_end_ms = 55033,
  word_timings = '[{"word":"Max","startIndex":0,"endIndex":3,"startMs":42670,"endMs":42820},{"word":"collected","startIndex":4,"endIndex":13,"startMs":42868,"endMs":43300},{"word":"some","startIndex":14,"endIndex":18,"startMs":43348,"endMs":43540},{"word":"rocks","startIndex":19,"endIndex":24,"startMs":43620,"endMs":44020},{"word":"to","startIndex":25,"endIndex":27,"startMs":44126,"endMs":44338},{"word":"bring","startIndex":28,"endIndex":33,"startMs":44378,"endMs":44578},{"word":"back","startIndex":34,"endIndex":38,"startMs":44642,"endMs":44898},{"word":"home.","startIndex":39,"endIndex":44,"startMs":44978,"endMs":45378},{"word":"Scientists","startIndex":45,"endIndex":55,"startMs":45530,"endMs":47050},{"word":"would","startIndex":56,"endIndex":61,"startMs":47076,"endMs":47206},{"word":"study","startIndex":62,"endIndex":67,"startMs":47272,"endMs":47602},{"word":"them","startIndex":68,"endIndex":72,"startMs":47650,"endMs":47842},{"word":"to","startIndex":73,"endIndex":75,"startMs":48002,"endMs":48322},{"word":"learn","startIndex":76,"endIndex":81,"startMs":48375,"endMs":48640},{"word":"more","startIndex":82,"endIndex":86,"startMs":48704,"endMs":48960},{"word":"about","startIndex":87,"endIndex":92,"startMs":49040,"endMs":49440},{"word":"Mars.","startIndex":93,"endIndex":98,"startMs":49568,"endMs":50160},{"word":"He","startIndex":99,"endIndex":101,"startMs":50533,"endMs":51279},{"word":"felt","startIndex":102,"endIndex":106,"startMs":51359,"endMs":51679},{"word":"like","startIndex":107,"endIndex":111,"startMs":51775,"endMs":52159},{"word":"the","startIndex":112,"endIndex":115,"startMs":52199,"endMs":52319},{"word":"luckiest","startIndex":116,"endIndex":124,"startMs":52383,"endMs":52959},{"word":"boy","startIndex":125,"endIndex":128,"startMs":53059,"endMs":53359},{"word":"in","startIndex":129,"endIndex":131,"startMs":53519,"endMs":53839},{"word":"the","startIndex":132,"endIndex":135,"startMs":53879,"endMs":53999},{"word":"universe!","startIndex":136,"endIndex":145,"startMs":54105,"endMs":55033}]'
WHERE id = 'cb000002-0002-0001-0001-000000000009';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb41/vKw6CTHP4m7pbqI90HqSX_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 12433,
  word_timings = '[{"word":"It","startIndex":0,"endIndex":2,"startMs":0,"endMs":80},{"word":"was","startIndex":3,"endIndex":6,"startMs":160,"endMs":400},{"word":"time","startIndex":7,"endIndex":11,"startMs":480,"endMs":800},{"word":"to","startIndex":12,"endIndex":14,"startMs":880,"endMs":1040},{"word":"go","startIndex":15,"endIndex":17,"startMs":1146,"endMs":1358},{"word":"home.","startIndex":18,"endIndex":23,"startMs":1470,"endMs":2558},{"word":"Max","startIndex":24,"endIndex":27,"startMs":2718,"endMs":3198},{"word":"waved","startIndex":28,"endIndex":33,"startMs":3264,"endMs":3594},{"word":"goodbye","startIndex":34,"endIndex":41,"startMs":3654,"endMs":4074},{"word":"to","startIndex":42,"endIndex":44,"startMs":4127,"endMs":4233},{"word":"Mars","startIndex":45,"endIndex":49,"startMs":4329,"endMs":4713},{"word":"and","startIndex":50,"endIndex":53,"startMs":4853,"endMs":5273},{"word":"climbed","startIndex":54,"endIndex":61,"startMs":5323,"endMs":5673},{"word":"back","startIndex":62,"endIndex":66,"startMs":5753,"endMs":6073},{"word":"into","startIndex":67,"endIndex":71,"startMs":6137,"endMs":6393},{"word":"the","startIndex":72,"endIndex":75,"startMs":6413,"endMs":6473},{"word":"rocket.","startIndex":76,"endIndex":83,"startMs":6553,"endMs":7113},{"word":"Earth,","startIndex":84,"endIndex":90,"startMs":7353,"endMs":8953},{"word":"here","startIndex":91,"endIndex":95,"startMs":9001,"endMs":9193},{"word":"we","startIndex":96,"endIndex":98,"startMs":9273,"endMs":9433},{"word":"come!","startIndex":99,"endIndex":104,"startMs":9513,"endMs":9993},{"word":"said","startIndex":105,"endIndex":109,"startMs":10121,"endMs":10633},{"word":"Captain","startIndex":110,"endIndex":117,"startMs":10683,"endMs":11033},{"word":"Luna.","startIndex":118,"endIndex":123,"startMs":11129,"endMs":12433}]'
WHERE id = 'cb000002-0003-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb41/vKw6CTHP4m7pbqI90HqSX_output.mp3',
  audio_start_ms = 13491,
  audio_end_ms = 27921,
  word_timings = '[{"word":"Three","startIndex":0,"endIndex":5,"startMs":13491,"endMs":13591},{"word":"days","startIndex":6,"endIndex":10,"startMs":13655,"endMs":13911},{"word":"later,","startIndex":11,"endIndex":17,"startMs":13977,"endMs":14627},{"word":"Max","startIndex":18,"endIndex":21,"startMs":14747,"endMs":15107},{"word":"saw","startIndex":22,"endIndex":25,"startMs":15187,"endMs":15427},{"word":"the","startIndex":26,"endIndex":29,"startMs":15467,"endMs":15587},{"word":"most","startIndex":30,"endIndex":34,"startMs":15651,"endMs":15907},{"word":"beautiful","startIndex":35,"endIndex":44,"startMs":15971,"endMs":16547},{"word":"sight","startIndex":45,"endIndex":50,"startMs":16640,"endMs":17105},{"word":"-","startIndex":51,"endIndex":52,"startMs":17625,"endMs":18145},{"word":"Earth!","startIndex":53,"endIndex":59,"startMs":18238,"endMs":18783},{"word":"It","startIndex":60,"endIndex":62,"startMs":19103,"endMs":19743},{"word":"was","startIndex":63,"endIndex":66,"startMs":19803,"endMs":19983},{"word":"blue","startIndex":67,"endIndex":71,"startMs":20111,"endMs":20623},{"word":"and","startIndex":72,"endIndex":75,"startMs":20703,"endMs":20943},{"word":"green","startIndex":76,"endIndex":81,"startMs":21063,"endMs":21663},{"word":"and","startIndex":82,"endIndex":85,"startMs":21743,"endMs":21983},{"word":"white.","startIndex":86,"endIndex":92,"startMs":22089,"endMs":22699},{"word":"It","startIndex":93,"endIndex":95,"startMs":22965,"endMs":23497},{"word":"looked","startIndex":96,"endIndex":102,"startMs":23554,"endMs":23896},{"word":"like","startIndex":103,"endIndex":107,"startMs":23944,"endMs":24136},{"word":"a","startIndex":108,"endIndex":109,"startMs":24176,"endMs":24216},{"word":"precious","startIndex":110,"endIndex":118,"startMs":24278,"endMs":24774},{"word":"marble","startIndex":119,"endIndex":125,"startMs":24865,"endMs":25411},{"word":"floating","startIndex":126,"endIndex":134,"startMs":25491,"endMs":26131},{"word":"in","startIndex":135,"endIndex":137,"startMs":26157,"endMs":26209},{"word":"the","startIndex":138,"endIndex":141,"startMs":26249,"endMs":26369},{"word":"darkness.","startIndex":142,"endIndex":151,"startMs":26457,"endMs":27921}]'
WHERE id = 'cb000002-0003-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb41/vKw6CTHP4m7pbqI90HqSX_output.mp3',
  audio_start_ms = 28730,
  audio_end_ms = 40898,
  word_timings = '[{"word":"The","startIndex":0,"endIndex":3,"startMs":28730,"endMs":28759},{"word":"rocket","startIndex":4,"endIndex":10,"startMs":28828,"endMs":29235},{"word":"landed","startIndex":11,"endIndex":17,"startMs":29304,"endMs":29711},{"word":"safely.","startIndex":18,"endIndex":25,"startMs":29802,"endMs":30869},{"word":"Max''s","startIndex":26,"endIndex":31,"startMs":30999,"endMs":31549},{"word":"family","startIndex":32,"endIndex":38,"startMs":31605,"endMs":31948},{"word":"was","startIndex":39,"endIndex":42,"startMs":31988,"endMs":32107},{"word":"waiting","startIndex":43,"endIndex":50,"startMs":32158,"endMs":32508},{"word":"for","startIndex":51,"endIndex":54,"startMs":32567,"endMs":32747},{"word":"him.","startIndex":55,"endIndex":59,"startMs":32808,"endMs":33068},{"word":"Welcome","startIndex":60,"endIndex":67,"startMs":33248,"endMs":34507},{"word":"home,","startIndex":68,"endIndex":73,"startMs":34588,"endMs":34988},{"word":"Space","startIndex":74,"endIndex":79,"startMs":35053,"endMs":35384},{"word":"Explorer!","startIndex":80,"endIndex":89,"startMs":35464,"endMs":36263},{"word":"they","startIndex":90,"endIndex":94,"startMs":36343,"endMs":36663},{"word":"cheered.","startIndex":95,"endIndex":103,"startMs":36714,"endMs":37144},{"word":"Max","startIndex":104,"endIndex":107,"startMs":37443,"endMs":38343},{"word":"hugged","startIndex":108,"endIndex":114,"startMs":38400,"endMs":38742},{"word":"everyone","startIndex":115,"endIndex":123,"startMs":38822,"endMs":39462},{"word":"tight.","startIndex":124,"endIndex":130,"startMs":39568,"endMs":40898}]'
WHERE id = 'cb000002-0003-0001-0001-000000000006';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb41/vKw6CTHP4m7pbqI90HqSX_output.mp3',
  audio_start_ms = 41793,
  audio_end_ms = 56218,
  word_timings = '[{"word":"That","startIndex":0,"endIndex":4,"startMs":41793,"endMs":41857},{"word":"night,","startIndex":5,"endIndex":11,"startMs":41922,"endMs":42653},{"word":"Max","startIndex":12,"endIndex":15,"startMs":42772,"endMs":43132},{"word":"looked","startIndex":16,"endIndex":22,"startMs":43166,"endMs":43370},{"word":"up","startIndex":23,"endIndex":25,"startMs":43424,"endMs":43529},{"word":"at","startIndex":26,"endIndex":28,"startMs":43556,"endMs":43608},{"word":"the","startIndex":29,"endIndex":32,"startMs":43647,"endMs":43767},{"word":"stars.","startIndex":33,"endIndex":39,"startMs":43873,"endMs":44563},{"word":"One","startIndex":40,"endIndex":43,"startMs":44843,"endMs":45683},{"word":"day,","startIndex":44,"endIndex":48,"startMs":45783,"endMs":46364},{"word":"he","startIndex":49,"endIndex":51,"startMs":46456,"endMs":46642},{"word":"said,","startIndex":52,"endIndex":57,"startMs":46706,"endMs":47363},{"word":"I","startIndex":58,"endIndex":59,"startMs":47562,"endMs":47763},{"word":"will","startIndex":60,"endIndex":64,"startMs":47794,"endMs":47922},{"word":"visit","startIndex":65,"endIndex":70,"startMs":47989,"endMs":48318},{"word":"every","startIndex":71,"endIndex":76,"startMs":48425,"endMs":48955},{"word":"planet","startIndex":77,"endIndex":83,"startMs":49022,"endMs":49431},{"word":"in","startIndex":84,"endIndex":86,"startMs":49483,"endMs":49589},{"word":"the","startIndex":87,"endIndex":90,"startMs":49629,"endMs":49749},{"word":"solar","startIndex":91,"endIndex":96,"startMs":49803,"endMs":50068},{"word":"system!","startIndex":97,"endIndex":104,"startMs":50147,"endMs":50708},{"word":"And","startIndex":105,"endIndex":108,"startMs":51007,"endMs":51908},{"word":"he","startIndex":109,"endIndex":111,"startMs":51961,"endMs":52067},{"word":"knew","startIndex":112,"endIndex":116,"startMs":52163,"endMs":52547},{"word":"that","startIndex":117,"endIndex":121,"startMs":52643,"endMs":53027},{"word":"his","startIndex":122,"endIndex":125,"startMs":53067,"endMs":53187},{"word":"space","startIndex":126,"endIndex":131,"startMs":53253,"endMs":53583},{"word":"adventures","startIndex":132,"endIndex":142,"startMs":53647,"endMs":54298},{"word":"were","startIndex":143,"endIndex":147,"startMs":54410,"endMs":54858},{"word":"just","startIndex":148,"endIndex":152,"startMs":54970,"endMs":55418},{"word":"beginning.","startIndex":153,"endIndex":163,"startMs":55490,"endMs":56218}]'
WHERE id = 'cb000002-0003-0001-0001-000000000008';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb45/q2IaDPDS1Nx8n58ELT8uK_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 12450,
  word_timings = '[{"word":"In","startIndex":0,"endIndex":2,"startMs":0,"endMs":160},{"word":"the","startIndex":3,"endIndex":6,"startMs":180,"endMs":240},{"word":"middle","startIndex":7,"endIndex":13,"startMs":274,"endMs":478},{"word":"of","startIndex":14,"endIndex":16,"startMs":531,"endMs":637},{"word":"Robot","startIndex":17,"endIndex":22,"startMs":717,"endMs":1117},{"word":"City,","startIndex":23,"endIndex":28,"startMs":1197,"endMs":1916},{"word":"there","startIndex":29,"endIndex":34,"startMs":1942,"endMs":2073},{"word":"was","startIndex":35,"endIndex":38,"startMs":2113,"endMs":2232},{"word":"a","startIndex":39,"endIndex":40,"startMs":2272,"endMs":2312},{"word":"big","startIndex":41,"endIndex":44,"startMs":2373,"endMs":2553},{"word":"factory","startIndex":45,"endIndex":52,"startMs":2632,"endMs":3192},{"word":"where","startIndex":53,"endIndex":58,"startMs":3258,"endMs":3588},{"word":"robots","startIndex":59,"endIndex":65,"startMs":3668,"endMs":4148},{"word":"were","startIndex":66,"endIndex":70,"startMs":4180,"endMs":4308},{"word":"made.","startIndex":71,"endIndex":76,"startMs":4372,"endMs":4789},{"word":"The","startIndex":77,"endIndex":80,"startMs":5048,"endMs":5829},{"word":"factory","startIndex":81,"endIndex":88,"startMs":5888,"endMs":6308},{"word":"was","startIndex":89,"endIndex":92,"startMs":6349,"endMs":6468},{"word":"busy","startIndex":93,"endIndex":97,"startMs":6580,"endMs":7029},{"word":"all","startIndex":98,"endIndex":101,"startMs":7088,"endMs":7269},{"word":"day","startIndex":102,"endIndex":105,"startMs":7369,"endMs":7669},{"word":"and","startIndex":106,"endIndex":109,"startMs":7749,"endMs":7989},{"word":"all","startIndex":110,"endIndex":113,"startMs":8109,"endMs":8469},{"word":"night,","startIndex":114,"endIndex":120,"startMs":8535,"endMs":9345},{"word":"building","startIndex":121,"endIndex":129,"startMs":9389,"endMs":9741},{"word":"robots","startIndex":130,"endIndex":136,"startMs":9809,"endMs":10216},{"word":"of","startIndex":137,"endIndex":139,"startMs":10323,"endMs":10535},{"word":"all","startIndex":140,"endIndex":143,"startMs":10635,"endMs":10934},{"word":"shapes","startIndex":144,"endIndex":150,"startMs":11015,"endMs":11495},{"word":"and","startIndex":151,"endIndex":154,"startMs":11555,"endMs":11735},{"word":"sizes.","startIndex":155,"endIndex":161,"startMs":11841,"endMs":12450}]'
WHERE id = 'cb000003-0001-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb45/q2IaDPDS1Nx8n58ELT8uK_output.mp3',
  audio_start_ms = 14068,
  audio_end_ms = 26427,
  word_timings = '[{"word":"One","startIndex":0,"endIndex":3,"startMs":14068,"endMs":14129},{"word":"day,","startIndex":4,"endIndex":8,"startMs":14189,"endMs":14849},{"word":"a","startIndex":9,"endIndex":10,"startMs":14889,"endMs":14929},{"word":"very","startIndex":11,"endIndex":15,"startMs":15009,"endMs":15329},{"word":"special","startIndex":16,"endIndex":23,"startMs":15389,"endMs":15809},{"word":"robot","startIndex":24,"endIndex":29,"startMs":15902,"endMs":16367},{"word":"was","startIndex":30,"endIndex":33,"startMs":16427,"endMs":16607},{"word":"created.","startIndex":34,"endIndex":42,"startMs":16677,"endMs":17327},{"word":"His","startIndex":43,"endIndex":46,"startMs":17506,"endMs":18047},{"word":"name","startIndex":47,"endIndex":51,"startMs":18127,"endMs":18447},{"word":"was","startIndex":52,"endIndex":55,"startMs":18547,"endMs":18847},{"word":"Beep,","startIndex":56,"endIndex":61,"startMs":18953,"endMs":19884},{"word":"and","startIndex":62,"endIndex":65,"startMs":19905,"endMs":19965},{"word":"he","startIndex":66,"endIndex":68,"startMs":20044,"endMs":20205},{"word":"was","startIndex":69,"endIndex":72,"startMs":20265,"endMs":20445},{"word":"the","startIndex":73,"endIndex":76,"startMs":20485,"endMs":20605},{"word":"smallest","startIndex":77,"endIndex":85,"startMs":20658,"endMs":21082},{"word":"robot","startIndex":86,"endIndex":91,"startMs":21175,"endMs":21640},{"word":"in","startIndex":92,"endIndex":94,"startMs":21692,"endMs":21799},{"word":"the","startIndex":95,"endIndex":98,"startMs":21839,"endMs":21959},{"word":"whole","startIndex":99,"endIndex":104,"startMs":22025,"endMs":22355},{"word":"factory.","startIndex":105,"endIndex":113,"startMs":22435,"endMs":23075},{"word":"He","startIndex":114,"endIndex":116,"startMs":23395,"endMs":24035},{"word":"was","startIndex":117,"endIndex":120,"startMs":24075,"endMs":24195},{"word":"only","startIndex":121,"endIndex":125,"startMs":24259,"endMs":24515},{"word":"as","startIndex":126,"endIndex":128,"startMs":24568,"endMs":24674},{"word":"tall","startIndex":129,"endIndex":133,"startMs":24754,"endMs":25074},{"word":"as","startIndex":134,"endIndex":136,"startMs":25180,"endMs":25392},{"word":"a","startIndex":137,"endIndex":138,"startMs":25432,"endMs":25472},{"word":"water","startIndex":139,"endIndex":144,"startMs":25538,"endMs":25868},{"word":"bottle!","startIndex":145,"endIndex":152,"startMs":25925,"endMs":26427}]'
WHERE id = 'cb000003-0001-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb45/q2IaDPDS1Nx8n58ELT8uK_output.mp3',
  audio_start_ms = 28126,
  audio_end_ms = 39766,
  word_timings = '[{"word":"You","startIndex":1,"endIndex":4,"startMs":28126,"endMs":28186},{"word":"are","startIndex":5,"endIndex":8,"startMs":28226,"endMs":28346},{"word":"too","startIndex":9,"endIndex":12,"startMs":28445,"endMs":28746},{"word":"small,","startIndex":13,"endIndex":19,"startMs":28852,"endMs":29942},{"word":"said","startIndex":20,"endIndex":24,"startMs":29990,"endMs":30182},{"word":"the","startIndex":25,"endIndex":28,"startMs":30202,"endMs":30262},{"word":"big","startIndex":29,"endIndex":32,"startMs":30322,"endMs":30502},{"word":"robots.","startIndex":33,"endIndex":40,"startMs":30593,"endMs":31299},{"word":"What","startIndex":41,"endIndex":45,"startMs":31427,"endMs":31939},{"word":"can","startIndex":46,"endIndex":49,"startMs":32019,"endMs":32259},{"word":"you","startIndex":50,"endIndex":53,"startMs":32319,"endMs":32499},{"word":"do?","startIndex":54,"endIndex":57,"startMs":32631,"endMs":32978},{"word":"Beep","startIndex":58,"endIndex":62,"startMs":33564,"endMs":34976},{"word":"felt","startIndex":63,"endIndex":67,"startMs":35040,"endMs":35296},{"word":"sad.","startIndex":68,"endIndex":72,"startMs":35416,"endMs":35936},{"word":"He","startIndex":73,"endIndex":75,"startMs":36149,"endMs":36575},{"word":"wanted","startIndex":76,"endIndex":82,"startMs":36632,"endMs":36974},{"word":"to","startIndex":83,"endIndex":85,"startMs":37027,"endMs":37133},{"word":"help,","startIndex":86,"endIndex":91,"startMs":37213,"endMs":37933},{"word":"but","startIndex":92,"endIndex":95,"startMs":37973,"endMs":38093},{"word":"nobody","startIndex":96,"endIndex":102,"startMs":38161,"endMs":38569},{"word":"gave","startIndex":103,"endIndex":107,"startMs":38617,"endMs":38809},{"word":"him","startIndex":108,"endIndex":111,"startMs":38849,"endMs":38969},{"word":"a","startIndex":112,"endIndex":113,"startMs":39009,"endMs":39049},{"word":"chance.","startIndex":114,"endIndex":121,"startMs":39140,"endMs":39766}]'
WHERE id = 'cb000003-0001-0001-0001-000000000007';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb45/q2IaDPDS1Nx8n58ELT8uK_output.mp3',
  audio_start_ms = 41384,
  audio_end_ms = 57186,
  word_timings = '[{"word":"But","startIndex":0,"endIndex":3,"startMs":41384,"endMs":41444},{"word":"Beep","startIndex":4,"endIndex":8,"startMs":41497,"endMs":41843},{"word":"never","startIndex":9,"endIndex":14,"startMs":41936,"endMs":42401},{"word":"gave","startIndex":15,"endIndex":19,"startMs":42465,"endMs":42721},{"word":"up.","startIndex":20,"endIndex":23,"startMs":42827,"endMs":43119},{"word":"He","startIndex":24,"endIndex":26,"startMs":43359,"endMs":43839},{"word":"practiced","startIndex":27,"endIndex":36,"startMs":43911,"endMs":44559},{"word":"and","startIndex":37,"endIndex":40,"startMs":44639,"endMs":44879},{"word":"practiced.","startIndex":41,"endIndex":51,"startMs":44967,"endMs":45839},{"word":"He","startIndex":52,"endIndex":54,"startMs":46079,"endMs":46559},{"word":"learned","startIndex":55,"endIndex":62,"startMs":46599,"endMs":46879},{"word":"to","startIndex":63,"endIndex":65,"startMs":46905,"endMs":46957},{"word":"climb,","startIndex":66,"endIndex":72,"startMs":47050,"endMs":47595},{"word":"to","startIndex":73,"endIndex":75,"startMs":47728,"endMs":47994},{"word":"jump,","startIndex":76,"endIndex":81,"startMs":48106,"endMs":48874},{"word":"and","startIndex":82,"endIndex":85,"startMs":48894,"endMs":48954},{"word":"to","startIndex":86,"endIndex":88,"startMs":49007,"endMs":49113},{"word":"squeeze","startIndex":89,"endIndex":96,"startMs":49173,"endMs":49593},{"word":"through","startIndex":97,"endIndex":104,"startMs":49633,"endMs":49913},{"word":"tiny","startIndex":105,"endIndex":109,"startMs":49993,"endMs":50313},{"word":"spaces.","startIndex":110,"endIndex":117,"startMs":50415,"endMs":51107},{"word":"One","startIndex":118,"endIndex":121,"startMs":51427,"endMs":52387},{"word":"day,","startIndex":122,"endIndex":126,"startMs":52467,"endMs":52947},{"word":"he","startIndex":127,"endIndex":129,"startMs":53027,"endMs":53187},{"word":"thought,","startIndex":130,"endIndex":138,"startMs":53227,"endMs":53587},{"word":"I","startIndex":139,"endIndex":140,"startMs":54067,"endMs":54547},{"word":"will","startIndex":141,"endIndex":145,"startMs":54579,"endMs":54707},{"word":"show","startIndex":146,"endIndex":150,"startMs":54771,"endMs":55027},{"word":"everyone","startIndex":151,"endIndex":159,"startMs":55107,"endMs":55747},{"word":"what","startIndex":160,"endIndex":164,"startMs":55811,"endMs":56067},{"word":"I","startIndex":165,"endIndex":166,"startMs":56267,"endMs":56467},{"word":"can","startIndex":167,"endIndex":170,"startMs":56527,"endMs":56707},{"word":"do!","startIndex":171,"endIndex":174,"startMs":56840,"endMs":57186}]'
WHERE id = 'cb000003-0001-0001-0001-000000000009';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb47/OMloAbjd6nDSBjmfPQNFR_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 15613,
  word_timings = '[{"word":"One","startIndex":0,"endIndex":3,"startMs":0,"endMs":240},{"word":"dark","startIndex":4,"endIndex":8,"startMs":320,"endMs":640},{"word":"night,","startIndex":9,"endIndex":15,"startMs":706,"endMs":1436},{"word":"something","startIndex":16,"endIndex":25,"startMs":1500,"endMs":2076},{"word":"terrible","startIndex":26,"endIndex":34,"startMs":2164,"endMs":2868},{"word":"happened.","startIndex":35,"endIndex":44,"startMs":2939,"endMs":3587},{"word":"The","startIndex":45,"endIndex":48,"startMs":3747,"endMs":4227},{"word":"city''s","startIndex":49,"endIndex":55,"startMs":4307,"endMs":4787},{"word":"power","startIndex":56,"endIndex":61,"startMs":4840,"endMs":5105},{"word":"station","startIndex":62,"endIndex":69,"startMs":5175,"endMs":5665},{"word":"broke","startIndex":70,"endIndex":75,"startMs":5718,"endMs":5983},{"word":"down!","startIndex":76,"endIndex":81,"startMs":6079,"endMs":6863},{"word":"All","startIndex":82,"endIndex":85,"startMs":6983,"endMs":7343},{"word":"the","startIndex":86,"endIndex":89,"startMs":7383,"endMs":7503},{"word":"lights","startIndex":90,"endIndex":96,"startMs":7560,"endMs":7902},{"word":"went","startIndex":97,"endIndex":101,"startMs":7950,"endMs":8142},{"word":"out.","startIndex":102,"endIndex":106,"startMs":8222,"endMs":8542},{"word":"All","startIndex":107,"endIndex":110,"startMs":8702,"endMs":9182},{"word":"the","startIndex":111,"endIndex":114,"startMs":9222,"endMs":9342},{"word":"machines","startIndex":115,"endIndex":123,"startMs":9439,"endMs":10215},{"word":"stopped","startIndex":124,"endIndex":131,"startMs":10295,"endMs":10855},{"word":"working.","startIndex":132,"endIndex":140,"startMs":10935,"endMs":11575},{"word":"Robot","startIndex":141,"endIndex":146,"startMs":11788,"endMs":12853},{"word":"City","startIndex":147,"endIndex":151,"startMs":12981,"endMs":13493},{"word":"was","startIndex":152,"endIndex":155,"startMs":13633,"endMs":14053},{"word":"in","startIndex":156,"endIndex":158,"startMs":14133,"endMs":14293},{"word":"trouble!","startIndex":159,"endIndex":167,"startMs":14363,"endMs":15613}]'
WHERE id = 'cb000003-0002-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb47/OMloAbjd6nDSBjmfPQNFR_output.mp3',
  audio_start_ms = 16532,
  audio_end_ms = 31620,
  word_timings = '[{"word":"We","startIndex":1,"endIndex":3,"startMs":16532,"endMs":16612},{"word":"need","startIndex":4,"endIndex":8,"startMs":16692,"endMs":17012},{"word":"to","startIndex":9,"endIndex":11,"startMs":17092,"endMs":17252},{"word":"fix","startIndex":12,"endIndex":15,"startMs":17352,"endMs":17652},{"word":"the","startIndex":16,"endIndex":19,"startMs":17692,"endMs":17812},{"word":"power","startIndex":20,"endIndex":25,"startMs":17865,"endMs":18130},{"word":"station!","startIndex":26,"endIndex":34,"startMs":18190,"endMs":18770},{"word":"shouted","startIndex":35,"endIndex":42,"startMs":18860,"endMs":19490},{"word":"the","startIndex":43,"endIndex":46,"startMs":19510,"endMs":19570},{"word":"Mayor.","startIndex":47,"endIndex":53,"startMs":19636,"endMs":20046},{"word":"But","startIndex":54,"endIndex":57,"startMs":20266,"endMs":20926},{"word":"there","startIndex":58,"endIndex":63,"startMs":20952,"endMs":21082},{"word":"was","startIndex":64,"endIndex":67,"startMs":21122,"endMs":21242},{"word":"a","startIndex":68,"endIndex":69,"startMs":21282,"endMs":21322},{"word":"big","startIndex":70,"endIndex":73,"startMs":21442,"endMs":21802},{"word":"problem.","startIndex":74,"endIndex":82,"startMs":21892,"endMs":22602},{"word":"The","startIndex":83,"endIndex":86,"startMs":22802,"endMs":23402},{"word":"broken","startIndex":87,"endIndex":93,"startMs":23470,"endMs":23878},{"word":"part","startIndex":94,"endIndex":98,"startMs":23974,"endMs":24358},{"word":"was","startIndex":99,"endIndex":102,"startMs":24438,"endMs":24678},{"word":"deep","startIndex":103,"endIndex":107,"startMs":24774,"endMs":25158},{"word":"inside","startIndex":108,"endIndex":114,"startMs":25260,"endMs":25872},{"word":"a","startIndex":115,"endIndex":116,"startMs":25992,"endMs":26112},{"word":"tiny","startIndex":117,"endIndex":121,"startMs":26240,"endMs":26752},{"word":"tunnel.","startIndex":122,"endIndex":129,"startMs":26843,"endMs":27469},{"word":"None","startIndex":130,"endIndex":134,"startMs":27709,"endMs":28669},{"word":"of","startIndex":135,"endIndex":137,"startMs":28749,"endMs":28909},{"word":"the","startIndex":138,"endIndex":141,"startMs":28929,"endMs":28989},{"word":"big","startIndex":142,"endIndex":145,"startMs":29069,"endMs":29309},{"word":"robots","startIndex":146,"endIndex":152,"startMs":29400,"endMs":29946},{"word":"could","startIndex":153,"endIndex":158,"startMs":30012,"endMs":30342},{"word":"fit","startIndex":159,"endIndex":162,"startMs":30442,"endMs":30742},{"word":"inside!","startIndex":163,"endIndex":170,"startMs":30856,"endMs":31620}]'
WHERE id = 'cb000003-0002-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb47/OMloAbjd6nDSBjmfPQNFR_output.mp3',
  audio_start_ms = 33339,
  audio_end_ms = 45768,
  word_timings = '[{"word":"I","startIndex":1,"endIndex":2,"startMs":33339,"endMs":33379},{"word":"can","startIndex":3,"endIndex":6,"startMs":33439,"endMs":33619},{"word":"help!","startIndex":7,"endIndex":12,"startMs":33699,"endMs":34179},{"word":"said","startIndex":13,"endIndex":17,"startMs":34307,"endMs":34819},{"word":"a","startIndex":18,"endIndex":19,"startMs":34899,"endMs":34979},{"word":"small","startIndex":20,"endIndex":25,"startMs":35032,"endMs":35297},{"word":"voice.","startIndex":26,"endIndex":32,"startMs":35390,"endMs":36015},{"word":"Everyone","startIndex":33,"endIndex":41,"startMs":36148,"endMs":37212},{"word":"turned","startIndex":42,"endIndex":48,"startMs":37269,"endMs":37611},{"word":"around.","startIndex":49,"endIndex":56,"startMs":37691,"endMs":38251},{"word":"It","startIndex":57,"endIndex":59,"startMs":38491,"endMs":38971},{"word":"was","startIndex":60,"endIndex":63,"startMs":39031,"endMs":39211},{"word":"Beep!","startIndex":64,"endIndex":69,"startMs":39291,"endMs":39851},{"word":"The","startIndex":70,"endIndex":73,"startMs":40091,"endMs":40811},{"word":"big","startIndex":74,"endIndex":77,"startMs":40891,"endMs":41131},{"word":"robots","startIndex":78,"endIndex":84,"startMs":41222,"endMs":41768},{"word":"laughed.","startIndex":85,"endIndex":93,"startMs":41848,"endMs":42488},{"word":"You?","startIndex":94,"endIndex":98,"startMs":42768,"endMs":44168},{"word":"You","startIndex":99,"endIndex":102,"startMs":44228,"endMs":44408},{"word":"are","startIndex":103,"endIndex":106,"startMs":44468,"endMs":44648},{"word":"too","startIndex":107,"endIndex":110,"startMs":44728,"endMs":44968},{"word":"small!","startIndex":111,"endIndex":117,"startMs":45088,"endMs":45768}]'
WHERE id = 'cb000003-0002-0001-0001-000000000007';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb47/OMloAbjd6nDSBjmfPQNFR_output.mp3',
  audio_start_ms = 46187,
  audio_end_ms = 61349,
  word_timings = '[{"word":"But","startIndex":0,"endIndex":3,"startMs":46187,"endMs":47207},{"word":"the","startIndex":4,"endIndex":7,"startMs":47227,"endMs":47287},{"word":"Mayor","startIndex":8,"endIndex":13,"startMs":47353,"endMs":47683},{"word":"said,","startIndex":14,"endIndex":19,"startMs":47747,"endMs":48083},{"word":"Wait.","startIndex":20,"endIndex":25,"startMs":48275,"endMs":49123},{"word":"Being","startIndex":26,"endIndex":31,"startMs":49269,"endMs":49999},{"word":"small","startIndex":32,"endIndex":37,"startMs":50079,"endMs":50479},{"word":"might","startIndex":38,"endIndex":43,"startMs":50532,"endMs":50797},{"word":"be","startIndex":44,"endIndex":46,"startMs":50850,"endMs":50956},{"word":"exactly","startIndex":47,"endIndex":54,"startMs":51066,"endMs":51836},{"word":"what","startIndex":55,"endIndex":59,"startMs":51916,"endMs":52236},{"word":"we","startIndex":60,"endIndex":62,"startMs":52342,"endMs":52554},{"word":"need!","startIndex":63,"endIndex":68,"startMs":52634,"endMs":53034},{"word":"She","startIndex":69,"endIndex":72,"startMs":53334,"endMs":54234},{"word":"gave","startIndex":73,"endIndex":77,"startMs":54298,"endMs":54554},{"word":"Beep","startIndex":78,"endIndex":82,"startMs":54634,"endMs":54954},{"word":"the","startIndex":83,"endIndex":86,"startMs":54994,"endMs":55114},{"word":"repair","startIndex":87,"endIndex":93,"startMs":55171,"endMs":55513},{"word":"tools","startIndex":94,"endIndex":99,"startMs":55593,"endMs":55993},{"word":"and","startIndex":100,"endIndex":103,"startMs":56113,"endMs":56473},{"word":"said,","startIndex":104,"endIndex":109,"startMs":56553,"endMs":57033},{"word":"We","startIndex":110,"endIndex":112,"startMs":57326,"endMs":57912},{"word":"believe","startIndex":113,"endIndex":120,"startMs":57972,"endMs":58391},{"word":"in","startIndex":121,"endIndex":123,"startMs":58418,"endMs":58470},{"word":"you,","startIndex":124,"endIndex":128,"startMs":58530,"endMs":58790},{"word":"Beep.","startIndex":129,"endIndex":134,"startMs":58843,"endMs":59189},{"word":"Go","startIndex":135,"endIndex":137,"startMs":59429,"endMs":59909},{"word":"save","startIndex":138,"endIndex":142,"startMs":60005,"endMs":60389},{"word":"our","startIndex":143,"endIndex":146,"startMs":60469,"endMs":60709},{"word":"city!","startIndex":147,"endIndex":152,"startMs":60805,"endMs":61349}]'
WHERE id = 'cb000003-0002-0001-0001-000000000009';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb49/ISOdZQPbRsSOf6p7Rsx3o_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 12786,
  word_timings = '[{"word":"Beep","startIndex":0,"endIndex":4,"startMs":0,"endMs":240},{"word":"squeezed","startIndex":5,"endIndex":13,"startMs":311,"endMs":879},{"word":"into","startIndex":14,"endIndex":18,"startMs":927,"endMs":1119},{"word":"the","startIndex":19,"endIndex":22,"startMs":1139,"endMs":1199},{"word":"tiny","startIndex":23,"endIndex":27,"startMs":1279,"endMs":1599},{"word":"tunnel.","startIndex":28,"endIndex":35,"startMs":1656,"endMs":2158},{"word":"It","startIndex":36,"endIndex":38,"startMs":2424,"endMs":2956},{"word":"was","startIndex":39,"endIndex":42,"startMs":3016,"endMs":3195},{"word":"dark","startIndex":43,"endIndex":47,"startMs":3292,"endMs":3675},{"word":"and","startIndex":48,"endIndex":51,"startMs":3756,"endMs":3995},{"word":"scary,","startIndex":52,"endIndex":58,"startMs":4101,"endMs":5192},{"word":"but","startIndex":59,"endIndex":62,"startMs":5231,"endMs":5351},{"word":"Beep","startIndex":63,"endIndex":67,"startMs":5404,"endMs":5670},{"word":"kept","startIndex":68,"endIndex":72,"startMs":5734,"endMs":5991},{"word":"going.","startIndex":73,"endIndex":79,"startMs":6044,"endMs":6468},{"word":"He","startIndex":80,"endIndex":82,"startMs":6709,"endMs":7189},{"word":"crawled","startIndex":83,"endIndex":90,"startMs":7239,"endMs":7589},{"word":"through","startIndex":91,"endIndex":98,"startMs":7619,"endMs":7829},{"word":"pipes","startIndex":99,"endIndex":104,"startMs":7909,"endMs":8309},{"word":"and","startIndex":105,"endIndex":108,"startMs":8409,"endMs":8709},{"word":"climbed","startIndex":109,"endIndex":116,"startMs":8759,"endMs":9109},{"word":"over","startIndex":117,"endIndex":121,"startMs":9157,"endMs":9349},{"word":"wires","startIndex":122,"endIndex":127,"startMs":9442,"endMs":9907},{"word":"until","startIndex":128,"endIndex":133,"startMs":9987,"endMs":10387},{"word":"he","startIndex":134,"endIndex":136,"startMs":10467,"endMs":10627},{"word":"found","startIndex":137,"endIndex":142,"startMs":10707,"endMs":11107},{"word":"the","startIndex":143,"endIndex":146,"startMs":11147,"endMs":11267},{"word":"broken","startIndex":147,"endIndex":153,"startMs":11324,"endMs":11666},{"word":"part.","startIndex":154,"endIndex":159,"startMs":11778,"endMs":12786}]'
WHERE id = 'cb000003-0003-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb49/ISOdZQPbRsSOf6p7Rsx3o_output.mp3',
  audio_start_ms = 13397,
  audio_end_ms = 28320,
  word_timings = '[{"word":"Beep","startIndex":0,"endIndex":4,"startMs":13397,"endMs":13663},{"word":"worked","startIndex":5,"endIndex":11,"startMs":13720,"endMs":14062},{"word":"quickly.","startIndex":12,"endIndex":20,"startMs":14132,"endMs":14702},{"word":"He","startIndex":21,"endIndex":23,"startMs":14915,"endMs":15341},{"word":"connected","startIndex":24,"endIndex":33,"startMs":15389,"endMs":15821},{"word":"the","startIndex":34,"endIndex":37,"startMs":15841,"endMs":15901},{"word":"wires,","startIndex":38,"endIndex":44,"startMs":15967,"endMs":16697},{"word":"tightened","startIndex":45,"endIndex":54,"startMs":16744,"endMs":17177},{"word":"the","startIndex":55,"endIndex":58,"startMs":17197,"endMs":17256},{"word":"bolts,","startIndex":59,"endIndex":65,"startMs":17337,"endMs":18137},{"word":"and","startIndex":66,"endIndex":69,"startMs":18177,"endMs":18297},{"word":"pressed","startIndex":70,"endIndex":77,"startMs":18346,"endMs":18697},{"word":"the","startIndex":78,"endIndex":81,"startMs":18756,"endMs":18936},{"word":"restart","startIndex":82,"endIndex":89,"startMs":19017,"endMs":19577},{"word":"button.","startIndex":90,"endIndex":97,"startMs":19633,"endMs":20055},{"word":"Suddenly,","startIndex":98,"endIndex":107,"startMs":20259,"endMs":22212},{"word":"the","startIndex":108,"endIndex":111,"startMs":22252,"endMs":22372},{"word":"lights","startIndex":112,"endIndex":118,"startMs":22416,"endMs":22687},{"word":"came","startIndex":119,"endIndex":123,"startMs":22750,"endMs":23006},{"word":"back","startIndex":124,"endIndex":128,"startMs":23070,"endMs":23327},{"word":"on","startIndex":129,"endIndex":131,"startMs":23433,"endMs":23645},{"word":"all","startIndex":132,"endIndex":135,"startMs":23765,"endMs":24125},{"word":"over","startIndex":136,"endIndex":140,"startMs":24221,"endMs":24605},{"word":"the","startIndex":141,"endIndex":144,"startMs":24625,"endMs":24685},{"word":"city!","startIndex":145,"endIndex":150,"startMs":24781,"endMs":25325},{"word":"Beep","startIndex":151,"endIndex":155,"startMs":25591,"endMs":26363},{"word":"had","startIndex":156,"endIndex":159,"startMs":26463,"endMs":26762},{"word":"done","startIndex":160,"endIndex":164,"startMs":26842,"endMs":27162},{"word":"it!","startIndex":165,"endIndex":168,"startMs":27269,"endMs":28320}]'
WHERE id = 'cb000003-0003-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb49/ISOdZQPbRsSOf6p7Rsx3o_output.mp3',
  audio_start_ms = 29256,
  audio_end_ms = 42266,
  word_timings = '[{"word":"When","startIndex":0,"endIndex":4,"startMs":29256,"endMs":29320},{"word":"Beep","startIndex":5,"endIndex":9,"startMs":29374,"endMs":29560},{"word":"came","startIndex":10,"endIndex":14,"startMs":29607,"endMs":29799},{"word":"out","startIndex":15,"endIndex":18,"startMs":29860,"endMs":30040},{"word":"of","startIndex":19,"endIndex":21,"startMs":30066,"endMs":30118},{"word":"the","startIndex":22,"endIndex":25,"startMs":30137,"endMs":30197},{"word":"tunnel,","startIndex":26,"endIndex":33,"startMs":30255,"endMs":30996},{"word":"everyone","startIndex":34,"endIndex":42,"startMs":31058,"endMs":31555},{"word":"was","startIndex":43,"endIndex":46,"startMs":31615,"endMs":31794},{"word":"cheering!","startIndex":47,"endIndex":56,"startMs":31866,"endMs":32513},{"word":"Beep!","startIndex":57,"endIndex":62,"startMs":32753,"endMs":33553},{"word":"Beep!","startIndex":63,"endIndex":68,"startMs":33634,"endMs":34114},{"word":"Beep!","startIndex":69,"endIndex":74,"startMs":34193,"endMs":34674},{"word":"they","startIndex":75,"endIndex":79,"startMs":34738,"endMs":34994},{"word":"shouted.","startIndex":80,"endIndex":88,"startMs":35053,"endMs":35634},{"word":"The","startIndex":89,"endIndex":92,"startMs":35854,"endMs":36513},{"word":"Mayor","startIndex":93,"endIndex":98,"startMs":36566,"endMs":36831},{"word":"gave","startIndex":99,"endIndex":103,"startMs":36895,"endMs":37151},{"word":"Beep","startIndex":104,"endIndex":108,"startMs":37205,"endMs":37630},{"word":"a","startIndex":109,"endIndex":110,"startMs":37711,"endMs":37791},{"word":"golden","startIndex":111,"endIndex":117,"startMs":37870,"endMs":38351},{"word":"medal.","startIndex":118,"endIndex":124,"startMs":38416,"endMs":38907},{"word":"You","startIndex":125,"endIndex":128,"startMs":39187,"endMs":40026},{"word":"are","startIndex":129,"endIndex":132,"startMs":40126,"endMs":40427},{"word":"a","startIndex":133,"endIndex":134,"startMs":40507,"endMs":40586},{"word":"hero!","startIndex":135,"endIndex":140,"startMs":40730,"endMs":41386},{"word":"she","startIndex":141,"endIndex":144,"startMs":41506,"endMs":41866},{"word":"said.","startIndex":145,"endIndex":150,"startMs":41930,"endMs":42266}]'
WHERE id = 'cb000003-0003-0001-0001-000000000007';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb49/ISOdZQPbRsSOf6p7Rsx3o_output.mp3',
  audio_start_ms = 43256,
  audio_end_ms = 58168,
  word_timings = '[{"word":"From","startIndex":0,"endIndex":4,"startMs":43256,"endMs":43864},{"word":"that","startIndex":5,"endIndex":9,"startMs":43913,"endMs":44105},{"word":"day","startIndex":10,"endIndex":13,"startMs":44164,"endMs":44344},{"word":"on,","startIndex":14,"endIndex":17,"startMs":44425,"endMs":44984},{"word":"nobody","startIndex":18,"endIndex":24,"startMs":45065,"endMs":45544},{"word":"laughed","startIndex":25,"endIndex":32,"startMs":45584,"endMs":45864},{"word":"at","startIndex":33,"endIndex":35,"startMs":45890,"endMs":45943},{"word":"Beep","startIndex":36,"endIndex":40,"startMs":46022,"endMs":46343},{"word":"anymore.","startIndex":41,"endIndex":49,"startMs":46413,"endMs":46983},{"word":"They","startIndex":50,"endIndex":54,"startMs":47142,"endMs":47782},{"word":"learned","startIndex":55,"endIndex":62,"startMs":47822,"endMs":48102},{"word":"an","startIndex":63,"endIndex":65,"startMs":48129,"endMs":48181},{"word":"important","startIndex":66,"endIndex":75,"startMs":48252,"endMs":48900},{"word":"lesson:","startIndex":76,"endIndex":83,"startMs":48968,"endMs":49857},{"word":"it","startIndex":84,"endIndex":86,"startMs":50016,"endMs":50336},{"word":"does","startIndex":87,"endIndex":91,"startMs":50385,"endMs":50577},{"word":"not","startIndex":92,"endIndex":95,"startMs":50636,"endMs":50816},{"word":"matter","startIndex":96,"endIndex":102,"startMs":50861,"endMs":51132},{"word":"how","startIndex":103,"endIndex":106,"startMs":51191,"endMs":51372},{"word":"big","startIndex":107,"endIndex":110,"startMs":51472,"endMs":51772},{"word":"or","startIndex":111,"endIndex":113,"startMs":51852,"endMs":52012},{"word":"small","startIndex":114,"endIndex":119,"startMs":52092,"endMs":52492},{"word":"you","startIndex":120,"endIndex":123,"startMs":52532,"endMs":52652},{"word":"are.","startIndex":124,"endIndex":128,"startMs":52712,"endMs":53052},{"word":"What","startIndex":129,"endIndex":133,"startMs":53212,"endMs":53852},{"word":"matters","startIndex":134,"endIndex":141,"startMs":53912,"endMs":54331},{"word":"is","startIndex":142,"endIndex":144,"startMs":54517,"endMs":54889},{"word":"how","startIndex":145,"endIndex":148,"startMs":54949,"endMs":55129},{"word":"brave","startIndex":149,"endIndex":154,"startMs":55223,"endMs":55687},{"word":"and","startIndex":155,"endIndex":158,"startMs":55748,"endMs":55928},{"word":"kind","startIndex":159,"endIndex":163,"startMs":56040,"endMs":56488},{"word":"you","startIndex":164,"endIndex":167,"startMs":56528,"endMs":56647},{"word":"are","startIndex":168,"endIndex":171,"startMs":56708,"endMs":56888},{"word":"inside!","startIndex":172,"endIndex":179,"startMs":57047,"endMs":58168}]'
WHERE id = 'cb000003-0003-0001-0001-000000000010';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4b/asUzKaQVm5PP0JGo7MquK_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 9977,
  word_timings = '[{"word":"Maya","startIndex":0,"endIndex":4,"startMs":0,"endMs":400},{"word":"loved","startIndex":5,"endIndex":10,"startMs":453,"endMs":718},{"word":"the","startIndex":11,"endIndex":14,"startMs":758,"endMs":878},{"word":"ocean","startIndex":15,"endIndex":20,"startMs":944,"endMs":1274},{"word":"more","startIndex":21,"endIndex":25,"startMs":1322,"endMs":1514},{"word":"than","startIndex":26,"endIndex":30,"startMs":1562,"endMs":1754},{"word":"anything","startIndex":31,"endIndex":39,"startMs":1816,"endMs":2312},{"word":"in","startIndex":40,"endIndex":42,"startMs":2392,"endMs":2552},{"word":"the","startIndex":43,"endIndex":46,"startMs":2572,"endMs":2632},{"word":"world.","startIndex":47,"endIndex":53,"startMs":2738,"endMs":3348},{"word":"She","startIndex":54,"endIndex":57,"startMs":3588,"endMs":4308},{"word":"lived","startIndex":58,"endIndex":63,"startMs":4348,"endMs":4548},{"word":"in","startIndex":64,"endIndex":66,"startMs":4601,"endMs":4707},{"word":"a","startIndex":67,"endIndex":68,"startMs":4747,"endMs":4787},{"word":"small","startIndex":69,"endIndex":74,"startMs":4840,"endMs":5104},{"word":"house","startIndex":75,"endIndex":80,"startMs":5185,"endMs":5585},{"word":"by","startIndex":81,"endIndex":83,"startMs":5638,"endMs":5744},{"word":"the","startIndex":84,"endIndex":87,"startMs":5764,"endMs":5824},{"word":"beach","startIndex":88,"endIndex":93,"startMs":5944,"endMs":6544},{"word":"and","startIndex":94,"endIndex":97,"startMs":6604,"endMs":6784},{"word":"spent","startIndex":98,"endIndex":103,"startMs":6850,"endMs":7180},{"word":"every","startIndex":104,"endIndex":109,"startMs":7233,"endMs":7497},{"word":"day","startIndex":110,"endIndex":113,"startMs":7577,"endMs":7818},{"word":"playing","startIndex":114,"endIndex":121,"startMs":7878,"endMs":8298},{"word":"in","startIndex":122,"endIndex":124,"startMs":8351,"endMs":8456},{"word":"the","startIndex":125,"endIndex":128,"startMs":8477,"endMs":8536},{"word":"waves.","startIndex":129,"endIndex":135,"startMs":8657,"endMs":9977}]'
WHERE id = 'cb000004-0001-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4b/asUzKaQVm5PP0JGo7MquK_output.mp3',
  audio_start_ms = 10817,
  audio_end_ms = 20968,
  word_timings = '[{"word":"One","startIndex":0,"endIndex":3,"startMs":10817,"endMs":10937},{"word":"sunny","startIndex":4,"endIndex":9,"startMs":10990,"endMs":11254},{"word":"morning,","startIndex":10,"endIndex":18,"startMs":11315,"endMs":12135},{"word":"Maya","startIndex":19,"endIndex":23,"startMs":12215,"endMs":12535},{"word":"saw","startIndex":24,"endIndex":27,"startMs":12615,"endMs":12855},{"word":"something","startIndex":28,"endIndex":37,"startMs":12895,"endMs":13254},{"word":"splashing","startIndex":38,"endIndex":47,"startMs":13315,"endMs":13812},{"word":"in","startIndex":48,"endIndex":50,"startMs":13839,"endMs":13891},{"word":"the","startIndex":51,"endIndex":54,"startMs":13911,"endMs":13971},{"word":"water.","startIndex":55,"endIndex":61,"startMs":14051,"endMs":14530},{"word":"She","startIndex":62,"endIndex":65,"startMs":14770,"endMs":15491},{"word":"swam","startIndex":66,"endIndex":70,"startMs":15543,"endMs":15809},{"word":"closer","startIndex":71,"endIndex":77,"startMs":15889,"endMs":16369},{"word":"and","startIndex":78,"endIndex":81,"startMs":16490,"endMs":16849},{"word":"could","startIndex":82,"endIndex":87,"startMs":16889,"endMs":17089},{"word":"not","startIndex":88,"endIndex":91,"startMs":17169,"endMs":17409},{"word":"believe","startIndex":92,"endIndex":99,"startMs":17470,"endMs":17889},{"word":"her","startIndex":100,"endIndex":103,"startMs":17950,"endMs":18130},{"word":"eyes","startIndex":104,"endIndex":108,"startMs":18226,"endMs":18610},{"word":"-","startIndex":109,"endIndex":110,"startMs":18970,"endMs":19330},{"word":"it","startIndex":111,"endIndex":113,"startMs":19383,"endMs":19488},{"word":"was","startIndex":114,"endIndex":117,"startMs":19528,"endMs":19648},{"word":"a","startIndex":118,"endIndex":119,"startMs":19688,"endMs":19728},{"word":"baby","startIndex":120,"endIndex":124,"startMs":19824,"endMs":20208},{"word":"dolphin!","startIndex":125,"endIndex":133,"startMs":20298,"endMs":20968}]'
WHERE id = 'cb000004-0001-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4b/asUzKaQVm5PP0JGo7MquK_output.mp3',
  audio_start_ms = 21757,
  audio_end_ms = 33477,
  word_timings = '[{"word":"The","startIndex":0,"endIndex":3,"startMs":21757,"endMs":22207},{"word":"dolphin","startIndex":4,"endIndex":11,"startMs":22277,"endMs":22767},{"word":"clicked","startIndex":12,"endIndex":19,"startMs":22827,"endMs":23247},{"word":"and","startIndex":20,"endIndex":23,"startMs":23287,"endMs":23407},{"word":"whistled","startIndex":24,"endIndex":32,"startMs":23460,"endMs":23965},{"word":"happily.","startIndex":33,"endIndex":41,"startMs":24035,"endMs":24605},{"word":"Hello,","startIndex":42,"endIndex":48,"startMs":24845,"endMs":26165},{"word":"little","startIndex":49,"endIndex":55,"startMs":26182,"endMs":26284},{"word":"one!","startIndex":56,"endIndex":60,"startMs":26364,"endMs":26684},{"word":"said","startIndex":61,"endIndex":65,"startMs":26812,"endMs":27324},{"word":"Maya.","startIndex":66,"endIndex":71,"startMs":27404,"endMs":27804},{"word":"I","startIndex":72,"endIndex":73,"startMs":28004,"endMs":28204},{"word":"will","startIndex":74,"endIndex":78,"startMs":28252,"endMs":28444},{"word":"call","startIndex":79,"endIndex":83,"startMs":28492,"endMs":28684},{"word":"you","startIndex":84,"endIndex":87,"startMs":28764,"endMs":29004},{"word":"Splash!","startIndex":88,"endIndex":95,"startMs":29141,"endMs":30043},{"word":"The","startIndex":96,"endIndex":99,"startMs":30323,"endMs":31163},{"word":"dolphin","startIndex":100,"endIndex":107,"startMs":31213,"endMs":31563},{"word":"seemed","startIndex":108,"endIndex":114,"startMs":31608,"endMs":31878},{"word":"to","startIndex":115,"endIndex":117,"startMs":31904,"endMs":31956},{"word":"like","startIndex":118,"endIndex":122,"startMs":32036,"endMs":32356},{"word":"the","startIndex":123,"endIndex":126,"startMs":32376,"endMs":32436},{"word":"name.","startIndex":127,"endIndex":132,"startMs":32516,"endMs":33477}]'
WHERE id = 'cb000004-0001-0001-0001-000000000007';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4b/asUzKaQVm5PP0JGo7MquK_output.mp3',
  audio_start_ms = 34211,
  audio_end_ms = 44093,
  word_timings = '[{"word":"From","startIndex":0,"endIndex":4,"startMs":34211,"endMs":34275},{"word":"that","startIndex":5,"endIndex":9,"startMs":34324,"endMs":34516},{"word":"day","startIndex":10,"endIndex":13,"startMs":34575,"endMs":34755},{"word":"on,","startIndex":14,"endIndex":17,"startMs":34809,"endMs":35394},{"word":"Maya","startIndex":18,"endIndex":22,"startMs":35458,"endMs":35714},{"word":"and","startIndex":23,"endIndex":26,"startMs":35754,"endMs":35874},{"word":"Splash","startIndex":27,"endIndex":33,"startMs":35942,"endMs":36350},{"word":"became","startIndex":34,"endIndex":40,"startMs":36407,"endMs":36749},{"word":"best","startIndex":41,"endIndex":45,"startMs":36845,"endMs":37229},{"word":"friends.","startIndex":46,"endIndex":54,"startMs":37299,"endMs":37869},{"word":"They","startIndex":55,"endIndex":59,"startMs":38029,"endMs":38669},{"word":"swam","startIndex":60,"endIndex":64,"startMs":38722,"endMs":38989},{"word":"together","startIndex":65,"endIndex":73,"startMs":39032,"endMs":39385},{"word":"every","startIndex":74,"endIndex":79,"startMs":39450,"endMs":39780},{"word":"day,","startIndex":80,"endIndex":84,"startMs":39880,"endMs":40580},{"word":"and","startIndex":85,"endIndex":88,"startMs":40600,"endMs":40660},{"word":"Splash","startIndex":89,"endIndex":95,"startMs":40728,"endMs":41136},{"word":"showed","startIndex":96,"endIndex":102,"startMs":41170,"endMs":41374},{"word":"Maya","startIndex":103,"endIndex":107,"startMs":41471,"endMs":41854},{"word":"all","startIndex":108,"endIndex":111,"startMs":41894,"endMs":42014},{"word":"the","startIndex":112,"endIndex":115,"startMs":42074,"endMs":42254},{"word":"secret","startIndex":116,"endIndex":122,"startMs":42311,"endMs":42654},{"word":"places","startIndex":123,"endIndex":129,"startMs":42733,"endMs":43213},{"word":"in","startIndex":130,"endIndex":132,"startMs":43266,"endMs":43372},{"word":"the","startIndex":133,"endIndex":136,"startMs":43413,"endMs":43532},{"word":"ocean.","startIndex":137,"endIndex":143,"startMs":43612,"endMs":44093}]'
WHERE id = 'cb000004-0001-0001-0001-000000000009';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4c/-WA7Wu7Ga4xpK2L9-S0ZS_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 12461,
  word_timings = '[{"word":"Follow","startIndex":1,"endIndex":7,"startMs":0,"endMs":240},{"word":"me!","startIndex":8,"endIndex":11,"startMs":346,"endMs":638},{"word":"clicked","startIndex":12,"endIndex":19,"startMs":708,"endMs":1198},{"word":"Splash","startIndex":20,"endIndex":26,"startMs":1266,"endMs":1674},{"word":"one","startIndex":27,"endIndex":30,"startMs":1714,"endMs":1834},{"word":"day.","startIndex":31,"endIndex":35,"startMs":1934,"endMs":2314},{"word":"Maya","startIndex":36,"endIndex":40,"startMs":2618,"endMs":3834},{"word":"put","startIndex":41,"endIndex":44,"startMs":3874,"endMs":3994},{"word":"on","startIndex":45,"endIndex":47,"startMs":4047,"endMs":4153},{"word":"her","startIndex":48,"endIndex":51,"startMs":4193,"endMs":4313},{"word":"goggles","startIndex":52,"endIndex":59,"startMs":4393,"endMs":4953},{"word":"and","startIndex":60,"endIndex":63,"startMs":5013,"endMs":5193},{"word":"dove","startIndex":64,"endIndex":68,"startMs":5289,"endMs":5673},{"word":"under","startIndex":69,"endIndex":74,"startMs":5726,"endMs":5991},{"word":"the","startIndex":75,"endIndex":78,"startMs":6011,"endMs":6071},{"word":"water.","startIndex":79,"endIndex":85,"startMs":6151,"endMs":6631},{"word":"Splash","startIndex":86,"endIndex":92,"startMs":6813,"endMs":7905},{"word":"led","startIndex":93,"endIndex":96,"startMs":7985,"endMs":8225},{"word":"her","startIndex":97,"endIndex":100,"startMs":8265,"endMs":8385},{"word":"to","startIndex":101,"endIndex":103,"startMs":8411,"endMs":8463},{"word":"the","startIndex":104,"endIndex":107,"startMs":8523,"endMs":8703},{"word":"most","startIndex":108,"endIndex":112,"startMs":8767,"endMs":9023},{"word":"amazing","startIndex":113,"endIndex":120,"startMs":9133,"endMs":9903},{"word":"place","startIndex":121,"endIndex":126,"startMs":9956,"endMs":10221},{"word":"she","startIndex":127,"endIndex":130,"startMs":10341,"endMs":10701},{"word":"had","startIndex":131,"endIndex":134,"startMs":10761,"endMs":10940},{"word":"ever","startIndex":135,"endIndex":139,"startMs":11020,"endMs":11341},{"word":"seen.","startIndex":140,"endIndex":145,"startMs":11437,"endMs":12461}]'
WHERE id = 'cb000004-0002-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4c/-WA7Wu7Ga4xpK2L9-S0ZS_output.mp3',
  audio_start_ms = 13206,
  audio_end_ms = 24917,
  word_timings = '[{"word":"It","startIndex":0,"endIndex":2,"startMs":13206,"endMs":13258},{"word":"was","startIndex":3,"endIndex":6,"startMs":13278,"endMs":13338},{"word":"a","startIndex":7,"endIndex":8,"startMs":13418,"endMs":13498},{"word":"coral","startIndex":9,"endIndex":14,"startMs":13564,"endMs":13894},{"word":"reef!","startIndex":15,"endIndex":20,"startMs":14006,"endMs":14533},{"word":"There","startIndex":21,"endIndex":26,"startMs":14693,"endMs":15494},{"word":"were","startIndex":27,"endIndex":31,"startMs":15526,"endMs":15654},{"word":"corals","startIndex":32,"endIndex":38,"startMs":15713,"endMs":16134},{"word":"of","startIndex":39,"endIndex":41,"startMs":16239,"endMs":16452},{"word":"every","startIndex":42,"endIndex":47,"startMs":16518,"endMs":16848},{"word":"color","startIndex":48,"endIndex":53,"startMs":16901,"endMs":17166},{"word":"-","startIndex":54,"endIndex":55,"startMs":17526,"endMs":17886},{"word":"pink,","startIndex":56,"endIndex":61,"startMs":17950,"endMs":18646},{"word":"purple,","startIndex":62,"endIndex":69,"startMs":18708,"endMs":19479},{"word":"orange,","startIndex":70,"endIndex":77,"startMs":19537,"endMs":19999},{"word":"and","startIndex":78,"endIndex":81,"startMs":20029,"endMs":20119},{"word":"blue.","startIndex":82,"endIndex":87,"startMs":20215,"endMs":21438},{"word":"Beautiful","startIndex":88,"endIndex":97,"startMs":21522,"endMs":22278},{"word":"fish","startIndex":98,"endIndex":102,"startMs":22359,"endMs":22678},{"word":"swam","startIndex":103,"endIndex":107,"startMs":22758,"endMs":23238},{"word":"all","startIndex":108,"endIndex":111,"startMs":23318,"endMs":23558},{"word":"around","startIndex":112,"endIndex":118,"startMs":23615,"endMs":23958},{"word":"them.","startIndex":119,"endIndex":124,"startMs":24022,"endMs":24917}]'
WHERE id = 'cb000004-0002-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4c/-WA7Wu7Ga4xpK2L9-S0ZS_output.mp3',
  audio_start_ms = 25700,
  audio_end_ms = 37123,
  word_timings = '[{"word":"Maya","startIndex":0,"endIndex":4,"startMs":25700,"endMs":25796},{"word":"saw","startIndex":5,"endIndex":8,"startMs":25856,"endMs":26036},{"word":"a","startIndex":9,"endIndex":10,"startMs":26116,"endMs":26196},{"word":"green","startIndex":11,"endIndex":16,"startMs":26262,"endMs":26592},{"word":"turtle","startIndex":17,"endIndex":23,"startMs":26660,"endMs":27068},{"word":"swimming","startIndex":24,"endIndex":32,"startMs":27156,"endMs":27860},{"word":"slowly","startIndex":33,"endIndex":39,"startMs":27928,"endMs":28336},{"word":"by.","startIndex":40,"endIndex":43,"startMs":28469,"endMs":28895},{"word":"An","startIndex":44,"endIndex":46,"startMs":29188,"endMs":29775},{"word":"octopus","startIndex":47,"endIndex":54,"startMs":29854,"endMs":30334},{"word":"waved","startIndex":55,"endIndex":60,"startMs":30414,"endMs":30814},{"word":"at","startIndex":61,"endIndex":63,"startMs":30840,"endMs":30892},{"word":"her","startIndex":64,"endIndex":67,"startMs":30952,"endMs":31132},{"word":"with","startIndex":68,"endIndex":72,"startMs":31180,"endMs":31372},{"word":"all","startIndex":73,"endIndex":76,"startMs":31452,"endMs":31692},{"word":"eight","startIndex":77,"endIndex":82,"startMs":31772,"endMs":32172},{"word":"arms.","startIndex":83,"endIndex":88,"startMs":32284,"endMs":32893},{"word":"A","startIndex":89,"endIndex":90,"startMs":33293,"endMs":33693},{"word":"school","startIndex":91,"endIndex":97,"startMs":33738,"endMs":34007},{"word":"of","startIndex":98,"endIndex":100,"startMs":34061,"endMs":34167},{"word":"tiny","startIndex":101,"endIndex":105,"startMs":34247,"endMs":34567},{"word":"silver","startIndex":106,"endIndex":112,"startMs":34635,"endMs":35043},{"word":"fish","startIndex":113,"endIndex":117,"startMs":35155,"endMs":35603},{"word":"sparkled","startIndex":118,"endIndex":126,"startMs":35683,"endMs":36323},{"word":"like","startIndex":127,"endIndex":131,"startMs":36371,"endMs":36563},{"word":"glitter.","startIndex":132,"endIndex":140,"startMs":36633,"endMs":37123}]'
WHERE id = 'cb000004-0002-0001-0001-000000000007';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4e/bjAcWTZiqgnLdzCMeCWRI_output.mp3',
  audio_start_ms = 0,
  audio_end_ms = 12223,
  word_timings = '[{"word":"Behind","startIndex":0,"endIndex":6,"startMs":0,"endMs":480},{"word":"the","startIndex":7,"endIndex":10,"startMs":520,"endMs":640},{"word":"coral","startIndex":11,"endIndex":16,"startMs":693,"endMs":958},{"word":"reef,","startIndex":17,"endIndex":22,"startMs":1038,"endMs":1678},{"word":"there","startIndex":23,"endIndex":28,"startMs":1691,"endMs":1756},{"word":"was","startIndex":29,"endIndex":32,"startMs":1796,"endMs":1916},{"word":"a","startIndex":33,"endIndex":34,"startMs":1956,"endMs":1996},{"word":"dark","startIndex":35,"endIndex":39,"startMs":2108,"endMs":2556},{"word":"cave.","startIndex":40,"endIndex":45,"startMs":2684,"endMs":3276},{"word":"Splash","startIndex":46,"endIndex":52,"startMs":3493,"endMs":4795},{"word":"clicked","startIndex":53,"endIndex":60,"startMs":4865,"endMs":5355},{"word":"excitedly","startIndex":61,"endIndex":70,"startMs":5425,"endMs":6075},{"word":"and","startIndex":71,"endIndex":74,"startMs":6195,"endMs":6555},{"word":"swam","startIndex":75,"endIndex":79,"startMs":6635,"endMs":6955},{"word":"inside.","startIndex":80,"endIndex":87,"startMs":7046,"endMs":7672},{"word":"Maya","startIndex":88,"endIndex":92,"startMs":7976,"endMs":9192},{"word":"followed","startIndex":93,"endIndex":101,"startMs":9227,"endMs":9507},{"word":"her","startIndex":102,"endIndex":105,"startMs":9547,"endMs":9667},{"word":"friend","startIndex":106,"endIndex":112,"startMs":9735,"endMs":10143},{"word":"into","startIndex":113,"endIndex":117,"startMs":10238,"endMs":10623},{"word":"the","startIndex":118,"endIndex":121,"startMs":10663,"endMs":10783},{"word":"mysterious","startIndex":122,"endIndex":132,"startMs":10863,"endMs":11663},{"word":"cave.","startIndex":133,"endIndex":138,"startMs":11759,"endMs":12223}]'
WHERE id = 'cb000004-0003-0001-0001-000000000001';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4e/bjAcWTZiqgnLdzCMeCWRI_output.mp3',
  audio_start_ms = 13891,
  audio_end_ms = 24134,
  word_timings = '[{"word":"Inside","startIndex":0,"endIndex":6,"startMs":13891,"endMs":14059},{"word":"the","startIndex":7,"endIndex":10,"startMs":14099,"endMs":14219},{"word":"cave,","startIndex":11,"endIndex":16,"startMs":14283,"endMs":14619},{"word":"Maya","startIndex":17,"endIndex":21,"startMs":14779,"endMs":15419},{"word":"saw","startIndex":22,"endIndex":25,"startMs":15499,"endMs":15739},{"word":"something","startIndex":26,"endIndex":35,"startMs":15779,"endMs":16139},{"word":"shining","startIndex":36,"endIndex":43,"startMs":16229,"endMs":16859},{"word":"on","startIndex":44,"endIndex":46,"startMs":16939,"endMs":17099},{"word":"the","startIndex":47,"endIndex":50,"startMs":17119,"endMs":17179},{"word":"sandy","startIndex":51,"endIndex":56,"startMs":17259,"endMs":17659},{"word":"floor.","startIndex":57,"endIndex":63,"startMs":17739,"endMs":18219},{"word":"It","startIndex":64,"endIndex":66,"startMs":18619,"endMs":19419},{"word":"was","startIndex":67,"endIndex":70,"startMs":19459,"endMs":19579},{"word":"an","startIndex":71,"endIndex":73,"startMs":19659,"endMs":19819},{"word":"old","startIndex":74,"endIndex":77,"startMs":19919,"endMs":20219},{"word":"treasure","startIndex":78,"endIndex":86,"startMs":20263,"endMs":20615},{"word":"chest","startIndex":87,"endIndex":92,"startMs":20695,"endMs":21095},{"word":"covered","startIndex":93,"endIndex":100,"startMs":21185,"endMs":21815},{"word":"in","startIndex":101,"endIndex":103,"startMs":21948,"endMs":22214},{"word":"seashells","startIndex":104,"endIndex":113,"startMs":22294,"endMs":23014},{"word":"and","startIndex":114,"endIndex":117,"startMs":23074,"endMs":23254},{"word":"seaweed!","startIndex":118,"endIndex":126,"startMs":23350,"endMs":24134}]'
WHERE id = 'cb000004-0003-0001-0001-000000000004';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4e/bjAcWTZiqgnLdzCMeCWRI_output.mp3',
  audio_start_ms = 25718,
  audio_end_ms = 40584,
  word_timings = '[{"word":"Maya","startIndex":0,"endIndex":4,"startMs":25718,"endMs":25814},{"word":"opened","startIndex":5,"endIndex":11,"startMs":25871,"endMs":26213},{"word":"the","startIndex":12,"endIndex":15,"startMs":26233,"endMs":26293},{"word":"chest","startIndex":16,"endIndex":21,"startMs":26373,"endMs":26773},{"word":"carefully.","startIndex":22,"endIndex":32,"startMs":26852,"endMs":27653},{"word":"Inside,","startIndex":33,"endIndex":40,"startMs":27881,"endMs":29529},{"word":"there","startIndex":41,"endIndex":46,"startMs":29575,"endMs":29805},{"word":"were","startIndex":47,"endIndex":51,"startMs":29820,"endMs":29884},{"word":"no","startIndex":52,"endIndex":54,"startMs":29965,"endMs":30125},{"word":"gold","startIndex":55,"endIndex":59,"startMs":30205,"endMs":30525},{"word":"coins","startIndex":60,"endIndex":65,"startMs":30618,"endMs":31083},{"word":"or","startIndex":66,"endIndex":68,"startMs":31136,"endMs":31241},{"word":"jewels.","startIndex":69,"endIndex":76,"startMs":31343,"endMs":32035},{"word":"Instead,","startIndex":77,"endIndex":85,"startMs":32186,"endMs":33715},{"word":"there","startIndex":86,"endIndex":91,"startMs":33729,"endMs":33794},{"word":"was","startIndex":92,"endIndex":95,"startMs":33833,"endMs":33954},{"word":"something","startIndex":96,"endIndex":105,"startMs":34002,"endMs":34434},{"word":"even","startIndex":106,"endIndex":110,"startMs":34546,"endMs":34994},{"word":"better","startIndex":111,"endIndex":117,"startMs":35085,"endMs":35631},{"word":"-","startIndex":118,"endIndex":119,"startMs":35951,"endMs":36271},{"word":"a","startIndex":120,"endIndex":121,"startMs":36311,"endMs":36351},{"word":"beautiful","startIndex":122,"endIndex":131,"startMs":36423,"endMs":37071},{"word":"pearl","startIndex":132,"endIndex":137,"startMs":37137,"endMs":37467},{"word":"necklace","startIndex":138,"endIndex":146,"startMs":37529,"endMs":38025},{"word":"and","startIndex":147,"endIndex":150,"startMs":38144,"endMs":38504},{"word":"an","startIndex":151,"endIndex":153,"startMs":38558,"endMs":38664},{"word":"old","startIndex":154,"endIndex":157,"startMs":38804,"endMs":39224},{"word":"map!","startIndex":158,"endIndex":162,"startMs":39364,"endMs":40584}]'
WHERE id = 'cb000004-0003-0001-0001-000000000007';

UPDATE content_blocks SET
  audio_url = 'https://v3b.fal.media/files/b/0a8cfb4e/bjAcWTZiqgnLdzCMeCWRI_output.mp3',
  audio_start_ms = 41526,
  audio_end_ms = 52395,
  word_timings = '[{"word":"More","startIndex":1,"endIndex":5,"startMs":41526,"endMs":41622},{"word":"adventures","startIndex":6,"endIndex":16,"startMs":41665,"endMs":42095},{"word":"await","startIndex":17,"endIndex":22,"startMs":42161,"endMs":42491},{"word":"us,","startIndex":23,"endIndex":26,"startMs":42544,"endMs":42890},{"word":"Splash!","startIndex":27,"endIndex":34,"startMs":42924,"endMs":43288},{"word":"Maya","startIndex":35,"endIndex":39,"startMs":43416,"endMs":43928},{"word":"said","startIndex":40,"endIndex":44,"startMs":43992,"endMs":44248},{"word":"happily.","startIndex":45,"endIndex":53,"startMs":44308,"endMs":44808},{"word":"She","startIndex":54,"endIndex":57,"startMs":45048,"endMs":45768},{"word":"hugged","startIndex":58,"endIndex":64,"startMs":45836,"endMs":46244},{"word":"her","startIndex":65,"endIndex":68,"startMs":46264,"endMs":46324},{"word":"dolphin","startIndex":69,"endIndex":76,"startMs":46384,"endMs":46804},{"word":"friend.","startIndex":77,"endIndex":84,"startMs":46861,"endMs":47363},{"word":"Together,","startIndex":85,"endIndex":94,"startMs":47505,"endMs":49121},{"word":"they","startIndex":95,"endIndex":99,"startMs":49153,"endMs":49281},{"word":"would","startIndex":100,"endIndex":105,"startMs":49294,"endMs":49359},{"word":"explore","startIndex":106,"endIndex":113,"startMs":49429,"endMs":49919},{"word":"every","startIndex":114,"endIndex":119,"startMs":50039,"endMs":50639},{"word":"corner","startIndex":120,"endIndex":126,"startMs":50730,"endMs":51276},{"word":"of","startIndex":127,"endIndex":129,"startMs":51409,"endMs":51675},{"word":"the","startIndex":130,"endIndex":133,"startMs":51695,"endMs":51755},{"word":"ocean!","startIndex":134,"endIndex":140,"startMs":51835,"endMs":52395}]'
WHERE id = 'cb000004-0003-0001-0001-000000000010';

-- ============================================
-- CHAPTER VOCABULARY (generated by Gemini AI)
-- ============================================

-- Book 1: The Magic Garden
UPDATE chapters SET
  vocabulary = '[{"word":"sunny","meaning":"güneşli","phonetic":"/ˈsʌni/","startIndex":4,"endIndex":9},{"word":"backyard","meaning":"arka bahçe","phonetic":"/ˈbækˌjɑːrd/","startIndex":74,"endIndex":82},{"word":"bushes","meaning":"çalılıklar","phonetic":"/ˈbʊʃɪz/","startIndex":213,"endIndex":219},{"word":"noticed","meaning":"fark etti","phonetic":"/ˈnoʊtɪst/","startIndex":254,"endIndex":261},{"word":"gate","meaning":"kapı","phonetic":"/ɡeɪt/","startIndex":286,"endIndex":290},{"word":"vines","meaning":"asma yaprakları","phonetic":"/vaɪnz/","startIndex":308,"endIndex":313},{"word":"strange","meaning":"garip","phonetic":"/streɪndʒ/","startIndex":319,"endIndex":326},{"word":"whispered","meaning":"fısıldadı","phonetic":"/ˈwɪspərd/","startIndex":333,"endIndex":342},{"word":"touched","meaning":"dokundu","phonetic":"/tʌtʃt/","startIndex":384,"endIndex":391},{"word":"gently","meaning":"nazikçe","phonetic":"/ˈdʒentli/","startIndex":508,"endIndex":514},{"word":"surprise","meaning":"şaşkınlık","phonetic":"/sərˈpraɪz/","startIndex":523,"endIndex":531},{"word":"creak","meaning":"gıcırtı","phonetic":"/kriːk/","startIndex":555,"endIndex":560}]'
WHERE id = '55555555-0002-0001-0001-000000000001';

UPDATE chapters SET
  vocabulary = '[{"word":"magical","meaning":"büyülü","phonetic":"/ˈmædʒɪkəl/","startIndex":15,"endIndex":22},{"word":"grew","meaning":"büyüdü","phonetic":"/ɡruː/","startIndex":47,"endIndex":51},{"word":"roses","meaning":"güller","phonetic":"/ˈroʊzɪz/","startIndex":69,"endIndex":74},{"word":"sunflowers","meaning":"ayçiçekleri","phonetic":"/ˈsʌnflaʊərz/","startIndex":83,"endIndex":93},{"word":"violets","meaning":"menekşeler","phonetic":"/ˈvaɪələts/","startIndex":102,"endIndex":109},{"word":"daisies","meaning":"papatyalar","phonetic":"/ˈdeɪziz/","startIndex":121,"endIndex":128},{"word":"ordinary","meaning":"sıradan","phonetic":"/ˈɔːrdəneri/","startIndex":149,"endIndex":157},{"word":"surprise","meaning":"şaşkınlık","phonetic":"/sərˈpraɪz/","startIndex":241,"endIndex":249},{"word":"laughed","meaning":"güldü","phonetic":"/læft/","startIndex":315,"endIndex":322},{"word":"melody","meaning":"melodi","phonetic":"/ˈmelədi/","startIndex":441,"endIndex":447},{"word":"harmony","meaning":"armoni","phonetic":"/ˈhɑːrməni/","startIndex":472,"endIndex":479},{"word":"wonder","meaning":"hayret","phonetic":"/ˈwʌndər/","startIndex":500,"endIndex":506},{"word":"breeze","meaning":"meltem","phonetic":"/briːz/","startIndex":602,"endIndex":608}]'
WHERE id = '55555555-0002-0001-0001-000000000002';

UPDATE chapters SET
  vocabulary = '[{"word":"noticed","meaning":"fark etti","phonetic":"/ˈnoʊtɪst/","startIndex":27,"endIndex":34},{"word":"flying","meaning":"uçan","phonetic":"/ˈflaɪɪŋ/","startIndex":45,"endIndex":51},{"word":"butterfly","meaning":"kelebek","phonetic":"/ˈbʌtərflaɪ/","startIndex":90,"endIndex":99},{"word":"wings","meaning":"kanatlar","phonetic":"/wɪŋz/","startIndex":123,"endIndex":128},{"word":"golden","meaning":"altın rengi","phonetic":"/ˈɡoʊldən/","startIndex":134,"endIndex":140},{"word":"sparkled","meaning":"parıldadı","phonetic":"/ˈspɑːrkəld/","startIndex":145,"endIndex":153},{"word":"sunlight","meaning":"güneş ışığı","phonetic":"/ˈsʌnlaɪt/","startIndex":161,"endIndex":169},{"word":"grant","meaning":"bahşetmek, vermek","phonetic":"/ɡrænt/","startIndex":244,"endIndex":249},{"word":"wish","meaning":"dilek","phonetic":"/wɪʃ/","startIndex":180,"endIndex":184},{"word":"magic","meaning":"sihirli","phonetic":"/ˈmædʒɪk/","startIndex":283,"endIndex":288},{"word":"glowed","meaning":"parladı","phonetic":"/ɡloʊd/","startIndex":506,"endIndex":512},{"word":"welcome","meaning":"ağırlamak, hoş geldin demek","phonetic":"/ˈwelkəm/","startIndex":583,"endIndex":590}]'
WHERE id = '55555555-0002-0001-0001-000000000003';

-- Book 2: Max's Space Adventure
UPDATE chapters SET
  vocabulary = '[{"word":"astronaut","meaning":"astronot, uzay adamı","phonetic":"/ˈæstrənɔːt/","startIndex":21,"endIndex":30},{"word":"mission","meaning":"görev","phonetic":"/ˈmɪʃən/","startIndex":113,"endIndex":120},{"word":"captain","meaning":"kaptan","phonetic":"/ˈkæptɪn/","startIndex":157,"endIndex":164},{"word":"helmet","meaning":"kask","phonetic":"/ˈhelmɪt/","startIndex":219,"endIndex":225},{"word":"rocket","meaning":"roket","phonetic":"/ˈrɒkɪt/","startIndex":260,"endIndex":266},{"word":"shouted","meaning":"bağırdı","phonetic":"/ˈʃaʊtɪd/","startIndex":180,"endIndex":187},{"word":"excitedly","meaning":"heyecanla","phonetic":"/ɪkˈsaɪtɪdli/","startIndex":188,"endIndex":197},{"word":"shiny","meaning":"parlak","phonetic":"/ˈʃaɪni/","startIndex":247,"endIndex":252},{"word":"blast off","meaning":"fırlatmak, havalanmak","phonetic":"/blæst ɒf/","startIndex":319,"endIndex":328},{"word":"firework","meaning":"havai fişek","phonetic":"/ˈfaɪərwɜːrk/","startIndex":375,"endIndex":383},{"word":"twinkling","meaning":"parıldayan","phonetic":"/ˈtwɪŋklɪŋ/","startIndex":522,"endIndex":531},{"word":"whispered","meaning":"fısıldadı","phonetic":"/ˈwɪspərd/","startIndex":547,"endIndex":556}]'
WHERE id = '55555555-0002-0002-0001-000000000001';

UPDATE chapters SET
  vocabulary = '[{"word":"flying","meaning":"uçmak","phonetic":"/ˈflaɪɪŋ/","startIndex":6,"endIndex":12},{"word":"saw","meaning":"gördü","phonetic":"/sɔː/","startIndex":41,"endIndex":44},{"word":"planet","meaning":"gezegen","phonetic":"/ˈplænɪt/","startIndex":64,"endIndex":70},{"word":"rocket","meaning":"roket","phonetic":"/ˈrɒkɪt/","startIndex":130,"endIndex":136},{"word":"landed","meaning":"indi","phonetic":"/ˈlændɪd/","startIndex":137,"endIndex":143},{"word":"gently","meaning":"nazikçe","phonetic":"/ˈdʒentli/","startIndex":144,"endIndex":150},{"word":"surface","meaning":"yüzey","phonetic":"/ˈsɜːrfɪs/","startIndex":162,"endIndex":169},{"word":"boots","meaning":"botlar","phonetic":"/buːts/","startIndex":194,"endIndex":199},{"word":"dust","meaning":"toz","phonetic":"/dʌst/","startIndex":265,"endIndex":269},{"word":"mountains","meaning":"dağlar","phonetic":"/ˈmaʊntɪnz/","startIndex":285,"endIndex":294},{"word":"collected","meaning":"topladı","phonetic":"/kəˈlektɪd/","startIndex":424,"endIndex":433},{"word":"scientists","meaning":"bilim insanları","phonetic":"/ˈsaɪəntɪsts/","startIndex":465,"endIndex":475}]'
WHERE id = '55555555-0002-0002-0001-000000000002';

UPDATE chapters SET
  vocabulary = '[{"word":"waved","meaning":"el salladı","phonetic":"/weɪvd/","startIndex":28,"endIndex":33},{"word":"rocket","meaning":"roket","phonetic":"/ˈrɒkɪt/","startIndex":76,"endIndex":82},{"word":"captain","meaning":"kaptan","phonetic":"/ˈkæptɪn/","startIndex":110,"endIndex":117},{"word":"sight","meaning":"görünüm","phonetic":"/saɪt/","startIndex":169,"endIndex":174},{"word":"precious","meaning":"değerli","phonetic":"/ˈpreʃəs/","startIndex":234,"endIndex":242},{"word":"marble","meaning":"bilye","phonetic":"/ˈmɑːrbl/","startIndex":243,"endIndex":249},{"word":"floating","meaning":"yüzen","phonetic":"/ˈfloʊtɪŋ/","startIndex":250,"endIndex":258},{"word":"darkness","meaning":"karanlık","phonetic":"/ˈdɑːrknəs/","startIndex":266,"endIndex":274},{"word":"landed","meaning":"indi","phonetic":"/ˈlændɪd/","startIndex":287,"endIndex":293},{"word":"explorer","meaning":"kaşif","phonetic":"/ɪkˈsplɔːrər/","startIndex":356,"endIndex":364},{"word":"cheered","meaning":"tezahürat yaptılar","phonetic":"/tʃɪrd/","startIndex":371,"endIndex":378},{"word":"adventures","meaning":"maceralar","phonetic":"/ədˈventʃərz/","startIndex":539,"endIndex":549}]'
WHERE id = '55555555-0002-0002-0001-000000000003';

-- Book 3: The Brave Little Robot
UPDATE chapters SET
  vocabulary = '[{"word":"factory","meaning":"fabrika","phonetic":"/ˈfæktəri/","startIndex":45,"endIndex":52},{"word":"building","meaning":"inşa etmek","phonetic":"/ˈbɪldɪŋ/","startIndex":121,"endIndex":129},{"word":"shapes","meaning":"şekiller","phonetic":"/ʃeɪps/","startIndex":144,"endIndex":150},{"word":"sizes","meaning":"boyutlar","phonetic":"/ˈsaɪzɪz/","startIndex":155,"endIndex":160},{"word":"created","meaning":"yaratıldı","phonetic":"/kriˈeɪtɪd/","startIndex":196,"endIndex":203},{"word":"smallest","meaning":"en küçük","phonetic":"/ˈsmɔːlɪst/","startIndex":239,"endIndex":247},{"word":"tall","meaning":"uzun","phonetic":"/tɔːl/","startIndex":291,"endIndex":295},{"word":"chance","meaning":"şans","phonetic":"/tʃæns/","startIndex":428,"endIndex":434},{"word":"practiced","meaning":"pratik yaptı","phonetic":"/ˈpræktɪst/","startIndex":463,"endIndex":472},{"word":"climb","meaning":"tırmanmak","phonetic":"/klaɪm/","startIndex":502,"endIndex":507},{"word":"jump","meaning":"zıplamak","phonetic":"/dʒʌmp/","startIndex":512,"endIndex":516},{"word":"squeeze","meaning":"sıkıştırmak","phonetic":"/skwiːz/","startIndex":525,"endIndex":532}]'
WHERE id = '55555555-0002-0003-0001-000000000001';

UPDATE chapters SET
  vocabulary = '[{"word":"terrible","meaning":"korkunç, berbat","phonetic":"/ˈterəbl/","startIndex":26,"endIndex":34},{"word":"power station","meaning":"elektrik santrali","phonetic":"/ˈpaʊər ˌsteɪʃn/","startIndex":56,"endIndex":69},{"word":"broke down","meaning":"bozuldu","phonetic":"/broʊk daʊn/","startIndex":70,"endIndex":80},{"word":"machines","meaning":"makineler","phonetic":"/məˈʃiːnz/","startIndex":115,"endIndex":123},{"word":"mayor","meaning":"belediye başkanı","phonetic":"/ˈmeɪər/","startIndex":214,"endIndex":219},{"word":"tunnel","meaning":"tünel","phonetic":"/ˈtʌnl/","startIndex":289,"endIndex":295},{"word":"fit","meaning":"sığmak","phonetic":"/fɪt/","startIndex":326,"endIndex":329},{"word":"laughed","meaning":"güldü","phonetic":"/læft/","startIndex":422,"endIndex":429},{"word":"repair","meaning":"tamir","phonetic":"/rɪˈper/","startIndex":542,"endIndex":548},{"word":"tools","meaning":"aletler","phonetic":"/tuːlz/","startIndex":549,"endIndex":554},{"word":"believe","meaning":"inanmak","phonetic":"/bɪˈliːv/","startIndex":568,"endIndex":575},{"word":"save","meaning":"kurtarmak","phonetic":"/seɪv/","startIndex":593,"endIndex":597}]'
WHERE id = '55555555-0002-0003-0001-000000000002';

UPDATE chapters SET
  vocabulary = '[{"word":"squeezed","meaning":"sıkıştı","phonetic":"/skwiːzd/","startIndex":5,"endIndex":13},{"word":"tunnel","meaning":"tünel","phonetic":"/ˈtʌnl/","startIndex":28,"endIndex":34},{"word":"crawled","meaning":"emekledi","phonetic":"/krɔːld/","startIndex":83,"endIndex":90},{"word":"pipes","meaning":"borular","phonetic":"/paɪps/","startIndex":99,"endIndex":104},{"word":"wires","meaning":"teller","phonetic":"/ˈwaɪərz/","startIndex":122,"endIndex":127},{"word":"broken","meaning":"bozuk","phonetic":"/ˈbroʊkən/","startIndex":147,"endIndex":153},{"word":"connected","meaning":"bağladı","phonetic":"/kəˈnektɪd/","startIndex":184,"endIndex":193},{"word":"tightened","meaning":"sıkılaştırdı","phonetic":"/ˈtaɪtənd/","startIndex":205,"endIndex":214},{"word":"bolts","meaning":"cıvatalar","phonetic":"/boʊlts/","startIndex":219,"endIndex":224},{"word":"restart","meaning":"yeniden başlatma","phonetic":"/ˌriːˈstɑːrt/","startIndex":242,"endIndex":249},{"word":"cheering","meaning":"tezahürat yapıyordu","phonetic":"/ˈtʃɪrɪŋ/","startIndex":376,"endIndex":384},{"word":"mayor","meaning":"belediye başkanı","phonetic":"/ˈmeɪər/","startIndex":422,"endIndex":427},{"word":"medal","meaning":"madalya","phonetic":"/ˈmedl/","startIndex":447,"endIndex":452},{"word":"brave","meaning":"cesur","phonetic":"/breɪv/","startIndex":629,"endIndex":634}]'
WHERE id = '55555555-0002-0003-0001-000000000003';

-- Book 4: Ocean Explorers
UPDATE chapters SET
  vocabulary = '[{"word":"ocean","meaning":"okyanus","phonetic":"/ˈoʊʃən/","startIndex":15,"endIndex":20},{"word":"beach","meaning":"sahil","phonetic":"/biːtʃ/","startIndex":88,"endIndex":93},{"word":"waves","meaning":"dalgalar","phonetic":"/weɪvz/","startIndex":129,"endIndex":134},{"word":"splashing","meaning":"sıçrayan","phonetic":"/ˈsplæʃɪŋ/","startIndex":174,"endIndex":183},{"word":"dolphin","meaning":"yunus","phonetic":"/ˈdɑːlfɪn/","startIndex":261,"endIndex":268},{"word":"clicked","meaning":"tıklattı","phonetic":"/klɪkt/","startIndex":282,"endIndex":289},{"word":"whistled","meaning":"ıslık çaldı","phonetic":"/ˈwɪsəld/","startIndex":294,"endIndex":302},{"word":"secret","meaning":"gizli","phonetic":"/ˈsiːkrət/","startIndex":519,"endIndex":525},{"word":"friends","meaning":"arkadaşlar","phonetic":"/frendz/","startIndex":449,"endIndex":456},{"word":"swam","meaning":"yüzdü","phonetic":"/swæm/","startIndex":202,"endIndex":206}]'
WHERE id = '55555555-0002-0004-0001-000000000001';

UPDATE chapters SET
  vocabulary = '[{"word":"clicked","meaning":"tıkladı","phonetic":"/klɪkt/","startIndex":11,"endIndex":18},{"word":"goggles","meaning":"deniz gözlüğü","phonetic":"/ˈɡɑːɡəlz/","startIndex":51,"endIndex":58},{"word":"dove","meaning":"daldı","phonetic":"/doʊv/","startIndex":63,"endIndex":67},{"word":"coral","meaning":"mercan","phonetic":"/ˈkɔːrəl/","startIndex":154,"endIndex":159},{"word":"reef","meaning":"resif","phonetic":"/riːf/","startIndex":160,"endIndex":164},{"word":"swam","meaning":"yüzdü","phonetic":"/swæm/","startIndex":248,"endIndex":252},{"word":"turtle","meaning":"kaplumbağa","phonetic":"/ˈtɜːrtl/","startIndex":287,"endIndex":293},{"word":"octopus","meaning":"ahtapot","phonetic":"/ˈɑːktəpʊs/","startIndex":317,"endIndex":324},{"word":"waved","meaning":"el salladı","phonetic":"/weɪvd/","startIndex":325,"endIndex":330},{"word":"arms","meaning":"kollar","phonetic":"/ɑːrmz/","startIndex":353,"endIndex":357},{"word":"school","meaning":"okul (balık sürüsü)","phonetic":"/skuːl/","startIndex":361,"endIndex":367},{"word":"sparkled","meaning":"parıldadı","phonetic":"/ˈspɑːrkəld/","startIndex":388,"endIndex":396}]'
WHERE id = '55555555-0002-0004-0001-000000000002';

UPDATE chapters SET
  vocabulary = '[{"word":"reef","meaning":"resif","phonetic":"/riːf/","startIndex":17,"endIndex":21},{"word":"cave","meaning":"mağara","phonetic":"/keɪv/","startIndex":40,"endIndex":44},{"word":"swam","meaning":"yüzdü","phonetic":"/swæm/","startIndex":75,"endIndex":79},{"word":"mysterious","meaning":"gizemli","phonetic":"/mɪˈstɪəriəs/","startIndex":122,"endIndex":132},{"word":"shining","meaning":"parıldayan","phonetic":"/ˈʃaɪnɪŋ/","startIndex":175,"endIndex":182},{"word":"treasure","meaning":"hazine","phonetic":"/ˈtreʒər/","startIndex":217,"endIndex":225},{"word":"chest","meaning":"sandık","phonetic":"/tʃest/","startIndex":226,"endIndex":231},{"word":"seashells","meaning":"deniz kabukları","phonetic":"/ˈsiːʃelz/","startIndex":243,"endIndex":252},{"word":"seaweed","meaning":"deniz yosunu","phonetic":"/ˈsiːwiːd/","startIndex":257,"endIndex":264},{"word":"pearl","meaning":"inci","phonetic":"/pɜːrl/","startIndex":398,"endIndex":403},{"word":"necklace","meaning":"kolye","phonetic":"/ˈnekləs/","startIndex":404,"endIndex":412},{"word":"map","meaning":"harita","phonetic":"/mæp/","startIndex":424,"endIndex":427},{"word":"explore","meaning":"keşfetmek","phonetic":"/ɪkˈsplɔːr/","startIndex":534,"endIndex":541}]'
WHERE id = '55555555-0002-0004-0001-000000000003';

-- ============================================
-- STORY VOCABULARY WORDS (for word-tap lookup)
-- ============================================
-- These words from the stories are added to vocabulary_words table
-- so they appear in the word-tap popup

INSERT INTO vocabulary_words (id, word, phonetic, meaning_tr, meaning_en, level, categories, example_sentences)
VALUES
-- Book 1: The Magic Garden
('11111111-0005-0001-0001-000000000001', 'sunny', '/ˈsʌni/', 'güneşli', 'bright with sunlight', 'A1', ARRAY['adjectives', 'weather'], ARRAY['One sunny morning, Lily walked into the backyard.']),
('11111111-0005-0001-0001-000000000002', 'backyard', '/ˈbækˌjɑːrd/', 'arka bahçe', 'the area behind a house', 'A1', ARRAY['nouns', 'places'], ARRAY['She loved playing in her grandmother''s backyard.']),
('11111111-0005-0001-0001-000000000003', 'bushes', '/ˈbʊʃɪz/', 'çalılıklar', 'small woody plants', 'A2', ARRAY['nouns', 'nature'], ARRAY['Behind the rose bushes, Lily saw something.']),
('11111111-0005-0001-0001-000000000004', 'noticed', '/ˈnoʊtɪst/', 'fark etti', 'became aware of something', 'A2', ARRAY['verbs'], ARRAY['Lily noticed a small wooden gate.']),
('11111111-0005-0001-0001-000000000005', 'gate', '/ɡeɪt/', 'kapı', 'a door in a fence or wall', 'A1', ARRAY['nouns', 'objects'], ARRAY['She saw a small wooden gate covered in vines.']),
('11111111-0005-0001-0001-000000000006', 'vines', '/vaɪnz/', 'asma yaprakları', 'climbing plants', 'A2', ARRAY['nouns', 'nature'], ARRAY['The gate was covered in green vines.']),
('11111111-0005-0001-0001-000000000007', 'strange', '/streɪndʒ/', 'garip', 'unusual or surprising', 'A2', ARRAY['adjectives'], ARRAY['How strange! Lily whispered.']),
('11111111-0005-0001-0001-000000000008', 'whispered', '/ˈwɪspərd/', 'fısıldadı', 'spoke very quietly', 'A2', ARRAY['verbs'], ARRAY['How strange! Lily whispered.']),
('11111111-0005-0001-0001-000000000009', 'touched', '/tʌtʃt/', 'dokundu', 'made contact with', 'A1', ARRAY['verbs'], ARRAY['She touched the old wood carefully.']),
('11111111-0005-0001-0001-000000000010', 'gently', '/ˈdʒentli/', 'nazikçe', 'in a soft, careful way', 'A2', ARRAY['adverbs'], ARRAY['Lily pushed the gate gently.']),
('11111111-0005-0001-0001-000000000011', 'creak', '/kriːk/', 'gıcırtı', 'a squeaky sound', 'B1', ARRAY['nouns', 'verbs'], ARRAY['The gate opened with a soft creak.']),
('11111111-0005-0001-0001-000000000012', 'magical', '/ˈmædʒɪkəl/', 'büyülü', 'having special powers', 'A2', ARRAY['adjectives'], ARRAY['The garden was magical!']),
('11111111-0005-0001-0001-000000000013', 'grew', '/ɡruː/', 'büyüdü', 'past tense of grow', 'A1', ARRAY['verbs'], ARRAY['Flowers of every color grew everywhere.']),
('11111111-0005-0001-0001-000000000014', 'roses', '/ˈroʊzɪz/', 'güller', 'flowers with thorns', 'A1', ARRAY['nouns', 'nature'], ARRAY['There were red roses in the garden.']),
('11111111-0005-0001-0001-000000000015', 'sunflowers', '/ˈsʌnflaʊərz/', 'ayçiçekleri', 'tall yellow flowers', 'A2', ARRAY['nouns', 'nature'], ARRAY['Yellow sunflowers grew in the garden.']),
('11111111-0005-0001-0001-000000000016', 'violets', '/ˈvaɪələts/', 'menekşeler', 'small purple flowers', 'A2', ARRAY['nouns', 'nature'], ARRAY['Purple violets bloomed everywhere.']),
('11111111-0005-0001-0001-000000000017', 'daisies', '/ˈdeɪziz/', 'papatyalar', 'white flowers with yellow centers', 'A2', ARRAY['nouns', 'nature'], ARRAY['White daisies added harmony.']),
('11111111-0005-0001-0001-000000000018', 'ordinary', '/ˈɔːrdəneri/', 'sıradan', 'not special or unusual', 'A2', ARRAY['adjectives'], ARRAY['These were not ordinary flowers.']),
('11111111-0005-0001-0001-000000000019', 'laughed', '/læft/', 'güldü', 'made happy sounds', 'A1', ARRAY['verbs'], ARRAY['Of course we can talk! laughed the rose.']),
('11111111-0005-0001-0001-000000000020', 'melody', '/ˈmelədi/', 'melodi', 'a tune or song', 'A2', ARRAY['nouns', 'music'], ARRAY['The sunflowers hummed the melody.']),
('11111111-0005-0001-0001-000000000021', 'harmony', '/ˈhɑːrməni/', 'armoni', 'musical sounds together', 'B1', ARRAY['nouns', 'music'], ARRAY['The daisies added harmony.']),
('11111111-0005-0001-0001-000000000022', 'breeze', '/briːz/', 'meltem', 'a light wind', 'A2', ARRAY['nouns', 'weather'], ARRAY['The flowers danced in the gentle breeze.']),
('11111111-0005-0001-0001-000000000023', 'wings', '/wɪŋz/', 'kanatlar', 'body parts for flying', 'A1', ARRAY['nouns', 'body'], ARRAY['Its wings were golden and sparkled.']),
('11111111-0005-0001-0001-000000000024', 'golden', '/ˈɡoʊldən/', 'altın rengi', 'the color of gold', 'A2', ARRAY['adjectives', 'colors'], ARRAY['Its wings were golden and sparkled.']),
('11111111-0005-0001-0001-000000000025', 'sparkled', '/ˈspɑːrkəld/', 'parıldadı', 'shined with light', 'A2', ARRAY['verbs'], ARRAY['Its wings sparkled in the sunlight.']),
('11111111-0005-0001-0001-000000000026', 'sunlight', '/ˈsʌnlaɪt/', 'güneş ışığı', 'light from the sun', 'A1', ARRAY['nouns', 'nature'], ARRAY['Its wings sparkled in the sunlight.']),
('11111111-0005-0001-0001-000000000027', 'grant', '/ɡrænt/', 'vermek, bahşetmek', 'to give or allow', 'B1', ARRAY['verbs'], ARRAY['I can grant one wish to anyone.']),
('11111111-0005-0001-0001-000000000028', 'glowed', '/ɡloʊd/', 'parladı', 'shined with light', 'A2', ARRAY['verbs'], ARRAY['The butterfly''s wings glowed brightly.']),
('11111111-0005-0001-0001-000000000029', 'welcome', '/ˈwelkəm/', 'hoş geldin', 'a greeting', 'A1', ARRAY['nouns', 'verbs'], ARRAY['The magic garden will always welcome you.']),

-- Book 2: Max''s Space Adventure
('11111111-0005-0002-0001-000000000001', 'astronaut', '/ˈæstrənɔːt/', 'astronot', 'a person who travels to space', 'A2', ARRAY['nouns', 'space'], ARRAY['Max was the youngest astronaut in the world.']),
('11111111-0005-0002-0001-000000000002', 'mission', '/ˈmɪʃən/', 'görev', 'an important task', 'A2', ARRAY['nouns'], ARRAY['Today was his first mission to space.']),
('11111111-0005-0002-0001-000000000003', 'captain', '/ˈkæptɪn/', 'kaptan', 'the leader of a ship or team', 'A1', ARRAY['nouns'], ARRAY['Are you ready, Max? asked Captain Luna.']),
('11111111-0005-0002-0001-000000000004', 'helmet', '/ˈhelmɪt/', 'kask', 'head protection', 'A2', ARRAY['nouns', 'objects'], ARRAY['He put on his space helmet.']),
('11111111-0005-0002-0001-000000000005', 'shouted', '/ˈʃaʊtɪd/', 'bağırdı', 'yelled loudly', 'A1', ARRAY['verbs'], ARRAY['Yes! Max shouted excitedly.']),
('11111111-0005-0002-0001-000000000006', 'excitedly', '/ɪkˈsaɪtɪdli/', 'heyecanla', 'with excitement', 'A2', ARRAY['adverbs'], ARRAY['Max shouted excitedly.']),
('11111111-0005-0002-0001-000000000007', 'shiny', '/ˈʃaɪni/', 'parlak', 'bright and reflective', 'A1', ARRAY['adjectives'], ARRAY['He climbed into the shiny silver rocket.']),
('11111111-0005-0002-0001-000000000008', 'firework', '/ˈfaɪərwɜːrk/', 'havai fişek', 'an explosive display', 'A2', ARRAY['nouns'], ARRAY['The rocket shot up like a giant firework.']),
('11111111-0005-0002-0001-000000000009', 'twinkling', '/ˈtwɪŋklɪŋ/', 'parıldayan', 'shining with small flashes', 'A2', ARRAY['adjectives'], ARRAY['Max saw millions of twinkling stars.']),
('11111111-0005-0002-0001-000000000010', 'flying', '/ˈflaɪɪŋ/', 'uçan', 'moving through the air', 'A1', ARRAY['verbs'], ARRAY['After flying for three days, Max saw Mars.']),
('11111111-0005-0002-0001-000000000011', 'landed', '/ˈlændɪd/', 'indi', 'came down to ground', 'A1', ARRAY['verbs'], ARRAY['The rocket landed gently on the red surface.']),
('11111111-0005-0002-0001-000000000012', 'surface', '/ˈsɜːrfɪs/', 'yüzey', 'the outside layer', 'A2', ARRAY['nouns'], ARRAY['The rocket landed on the red surface.']),
('11111111-0005-0002-0001-000000000013', 'boots', '/buːts/', 'botlar', 'shoes that cover ankles', 'A1', ARRAY['nouns', 'clothing'], ARRAY['Max put on his special boots.']),
('11111111-0005-0002-0001-000000000014', 'dust', '/dʌst/', 'toz', 'fine dry particles', 'A2', ARRAY['nouns'], ARRAY['The ground was covered in red dust.']),
('11111111-0005-0002-0001-000000000015', 'mountains', '/ˈmaʊntɪnz/', 'dağlar', 'very high hills', 'A1', ARRAY['nouns', 'nature'], ARRAY['Look at those mountains!']),
('11111111-0005-0002-0001-000000000016', 'collected', '/kəˈlektɪd/', 'topladı', 'gathered together', 'A2', ARRAY['verbs'], ARRAY['Max collected some rocks.']),
('11111111-0005-0002-0001-000000000017', 'scientists', '/ˈsaɪəntɪsts/', 'bilim insanları', 'people who study science', 'A2', ARRAY['nouns'], ARRAY['Scientists would study the rocks.']),
('11111111-0005-0002-0001-000000000018', 'waved', '/weɪvd/', 'el salladı', 'moved hand to say goodbye', 'A1', ARRAY['verbs'], ARRAY['Max waved goodbye to Mars.']),
('11111111-0005-0002-0001-000000000019', 'sight', '/saɪt/', 'görünüm', 'something you see', 'A2', ARRAY['nouns'], ARRAY['Max saw the most beautiful sight.']),
('11111111-0005-0002-0001-000000000020', 'precious', '/ˈpreʃəs/', 'değerli', 'very valuable', 'B1', ARRAY['adjectives'], ARRAY['It looked like a precious marble.']),
('11111111-0005-0002-0001-000000000021', 'marble', '/ˈmɑːrbl/', 'bilye', 'a small glass ball', 'A2', ARRAY['nouns'], ARRAY['Earth looked like a precious marble.']),
('11111111-0005-0002-0001-000000000022', 'floating', '/ˈfloʊtɪŋ/', 'yüzen', 'staying on top of liquid or air', 'A2', ARRAY['verbs'], ARRAY['A marble floating in the darkness.']),
('11111111-0005-0002-0001-000000000023', 'darkness', '/ˈdɑːrknəs/', 'karanlık', 'absence of light', 'A2', ARRAY['nouns'], ARRAY['Floating in the darkness of space.']),
('11111111-0005-0002-0001-000000000024', 'explorer', '/ɪkˈsplɔːrər/', 'kaşif', 'someone who explores', 'A2', ARRAY['nouns'], ARRAY['Welcome home, Space Explorer!']),
('11111111-0005-0002-0001-000000000025', 'cheered', '/tʃɪrd/', 'tezahürat yaptı', 'shouted with joy', 'A2', ARRAY['verbs'], ARRAY['His family cheered for him.']),
('11111111-0005-0002-0001-000000000026', 'adventures', '/ədˈventʃərz/', 'maceralar', 'exciting experiences', 'A2', ARRAY['nouns'], ARRAY['His space adventures were just beginning.']),

-- Book 3: The Brave Little Robot
('11111111-0005-0003-0001-000000000001', 'building', '/ˈbɪldɪŋ/', 'inşa etmek', 'making or constructing', 'A1', ARRAY['verbs'], ARRAY['The factory was busy building robots.']),
('11111111-0005-0003-0001-000000000002', 'shapes', '/ʃeɪps/', 'şekiller', 'forms or outlines', 'A1', ARRAY['nouns'], ARRAY['Robots of all shapes and sizes.']),
('11111111-0005-0003-0001-000000000003', 'sizes', '/ˈsaɪzɪz/', 'boyutlar', 'how big or small things are', 'A1', ARRAY['nouns'], ARRAY['Robots of all shapes and sizes.']),
('11111111-0005-0003-0001-000000000004', 'created', '/kriˈeɪtɪd/', 'yaratıldı', 'was made', 'A2', ARRAY['verbs'], ARRAY['A very special robot was created.']),
('11111111-0005-0003-0001-000000000005', 'smallest', '/ˈsmɔːlɪst/', 'en küçük', 'the most small', 'A1', ARRAY['adjectives'], ARRAY['He was the smallest robot in the factory.']),
('11111111-0005-0003-0001-000000000006', 'tall', '/tɔːl/', 'uzun', 'having great height', 'A1', ARRAY['adjectives'], ARRAY['He was only as tall as a water bottle!']),
('11111111-0005-0003-0001-000000000007', 'chance', '/tʃæns/', 'şans', 'an opportunity', 'A2', ARRAY['nouns'], ARRAY['Nobody gave him a chance.']),
('11111111-0005-0003-0001-000000000008', 'practiced', '/ˈpræktɪst/', 'pratik yaptı', 'repeated to improve', 'A2', ARRAY['verbs'], ARRAY['He practiced and practiced.']),
('11111111-0005-0003-0001-000000000009', 'climb', '/klaɪm/', 'tırmanmak', 'to go up', 'A1', ARRAY['verbs'], ARRAY['He learned to climb.']),
('11111111-0005-0003-0001-000000000010', 'squeeze', '/skwiːz/', 'sıkıştırmak', 'to press tightly', 'A2', ARRAY['verbs'], ARRAY['He learned to squeeze through tiny spaces.']),
('11111111-0005-0003-0001-000000000011', 'terrible', '/ˈterəbl/', 'korkunç', 'very bad', 'A2', ARRAY['adjectives'], ARRAY['Something terrible happened.']),
('11111111-0005-0003-0001-000000000012', 'machines', '/məˈʃiːnz/', 'makineler', 'devices that do work', 'A2', ARRAY['nouns'], ARRAY['All the machines stopped working.']),
('11111111-0005-0003-0001-000000000013', 'mayor', '/ˈmeɪər/', 'belediye başkanı', 'the leader of a city', 'A2', ARRAY['nouns'], ARRAY['We need to fix it! shouted the Mayor.']),
('11111111-0005-0003-0001-000000000014', 'tunnel', '/ˈtʌnl/', 'tünel', 'an underground passage', 'A2', ARRAY['nouns'], ARRAY['The broken part was deep inside a tiny tunnel.']),
('11111111-0005-0003-0001-000000000015', 'fit', '/fɪt/', 'sığmak', 'to be the right size', 'A1', ARRAY['verbs'], ARRAY['None of the big robots could fit inside!']),
('11111111-0005-0003-0001-000000000016', 'repair', '/rɪˈper/', 'tamir', 'to fix something broken', 'A2', ARRAY['verbs', 'nouns'], ARRAY['She gave Beep the repair tools.']),
('11111111-0005-0003-0001-000000000017', 'tools', '/tuːlz/', 'aletler', 'instruments for work', 'A2', ARRAY['nouns'], ARRAY['She gave Beep the repair tools.']),
('11111111-0005-0003-0001-000000000018', 'believe', '/bɪˈliːv/', 'inanmak', 'to think something is true', 'A2', ARRAY['verbs'], ARRAY['We believe in you, Beep.']),
('11111111-0005-0003-0001-000000000019', 'save', '/seɪv/', 'kurtarmak', 'to rescue', 'A1', ARRAY['verbs'], ARRAY['Go save our city!']),
('11111111-0005-0003-0001-000000000020', 'squeezed', '/skwiːzd/', 'sıkıştı', 'pressed into tight space', 'A2', ARRAY['verbs'], ARRAY['Beep squeezed into the tiny tunnel.']),
('11111111-0005-0003-0001-000000000021', 'crawled', '/krɔːld/', 'emekledi', 'moved on hands and knees', 'A2', ARRAY['verbs'], ARRAY['He crawled through pipes.']),
('11111111-0005-0003-0001-000000000022', 'pipes', '/paɪps/', 'borular', 'tubes for carrying liquids', 'A2', ARRAY['nouns'], ARRAY['He crawled through pipes.']),
('11111111-0005-0003-0001-000000000023', 'wires', '/ˈwaɪərz/', 'teller', 'thin metal threads', 'A2', ARRAY['nouns'], ARRAY['He climbed over wires.']),
('11111111-0005-0003-0001-000000000024', 'broken', '/ˈbroʊkən/', 'bozuk', 'damaged, not working', 'A1', ARRAY['adjectives'], ARRAY['He found the broken part.']),
('11111111-0005-0003-0001-000000000025', 'connected', '/kəˈnektɪd/', 'bağladı', 'joined together', 'A2', ARRAY['verbs'], ARRAY['He connected the wires.']),
('11111111-0005-0003-0001-000000000026', 'tightened', '/ˈtaɪtənd/', 'sıkılaştırdı', 'made more tight', 'A2', ARRAY['verbs'], ARRAY['He tightened the bolts.']),
('11111111-0005-0003-0001-000000000027', 'bolts', '/boʊlts/', 'cıvatalar', 'metal fasteners', 'B1', ARRAY['nouns'], ARRAY['He tightened the bolts.']),
('11111111-0005-0003-0001-000000000028', 'restart', '/ˌriːˈstɑːrt/', 'yeniden başlatma', 'to start again', 'A2', ARRAY['verbs', 'nouns'], ARRAY['He pressed the restart button.']),
('11111111-0005-0003-0001-000000000029', 'cheering', '/ˈtʃɪrɪŋ/', 'tezahürat yapan', 'shouting with joy', 'A2', ARRAY['verbs'], ARRAY['Everyone was cheering!']),
('11111111-0005-0003-0001-000000000030', 'medal', '/ˈmedl/', 'madalya', 'an award for achievement', 'A2', ARRAY['nouns'], ARRAY['The Mayor gave Beep a golden medal.']),

-- Book 4: Ocean Explorers
('11111111-0005-0004-0001-000000000001', 'beach', '/biːtʃ/', 'sahil', 'sandy area by the sea', 'A1', ARRAY['nouns', 'nature'], ARRAY['She lived in a small house by the beach.']),
('11111111-0005-0004-0001-000000000002', 'waves', '/weɪvz/', 'dalgalar', 'moving water in the sea', 'A1', ARRAY['nouns', 'nature'], ARRAY['She spent every day playing in the waves.']),
('11111111-0005-0004-0001-000000000003', 'splashing', '/ˈsplæʃɪŋ/', 'sıçrayan', 'making water fly around', 'A2', ARRAY['verbs'], ARRAY['Maya saw something splashing in the water.']),
('11111111-0005-0004-0001-000000000004', 'clicked', '/klɪkt/', 'tıklattı', 'made a sharp sound', 'A2', ARRAY['verbs'], ARRAY['The dolphin clicked and whistled happily.']),
('11111111-0005-0004-0001-000000000005', 'whistled', '/ˈwɪsəld/', 'ıslık çaldı', 'made a high sound', 'A2', ARRAY['verbs'], ARRAY['The dolphin clicked and whistled.']),
('11111111-0005-0004-0001-000000000006', 'swam', '/swæm/', 'yüzdü', 'moved through water', 'A1', ARRAY['verbs'], ARRAY['They swam together every day.']),
('11111111-0005-0004-0001-000000000007', 'goggles', '/ˈɡɑːɡəlz/', 'gözlük', 'glasses for swimming', 'A2', ARRAY['nouns'], ARRAY['Maya put on her goggles.']),
('11111111-0005-0004-0001-000000000008', 'dove', '/doʊv/', 'daldı', 'went underwater', 'A2', ARRAY['verbs'], ARRAY['Maya dove under the water.']),
('11111111-0005-0004-0001-000000000009', 'coral', '/ˈkɔːrəl/', 'mercan', 'hard sea structure', 'A2', ARRAY['nouns', 'sea'], ARRAY['It was a coral reef!']),
('11111111-0005-0004-0001-000000000010', 'reef', '/riːf/', 'resif', 'rocky area in the sea', 'A2', ARRAY['nouns', 'sea'], ARRAY['It was a beautiful coral reef!']),
('11111111-0005-0004-0001-000000000011', 'turtle', '/ˈtɜːrtl/', 'kaplumbağa', 'a reptile with a shell', 'A1', ARRAY['nouns', 'animals'], ARRAY['Maya saw a green turtle swimming slowly.']),
('11111111-0005-0004-0001-000000000012', 'octopus', '/ˈɑːktəpʊs/', 'ahtapot', 'sea animal with eight arms', 'A2', ARRAY['nouns', 'animals'], ARRAY['An octopus waved at her with all eight arms.']),
('11111111-0005-0004-0001-000000000013', 'arms', '/ɑːrmz/', 'kollar', 'body parts used for holding', 'A1', ARRAY['nouns', 'body'], ARRAY['The octopus waved with all eight arms.']),
('11111111-0005-0004-0001-000000000014', 'cave', '/keɪv/', 'mağara', 'a hole in rock or mountain', 'A2', ARRAY['nouns', 'nature'], ARRAY['There was a dark cave behind the reef.']),
('11111111-0005-0004-0001-000000000015', 'mysterious', '/mɪˈstɪəriəs/', 'gizemli', 'strange and unknown', 'B1', ARRAY['adjectives'], ARRAY['Maya followed into the mysterious cave.']),
('11111111-0005-0004-0001-000000000016', 'shining', '/ˈʃaɪnɪŋ/', 'parıldayan', 'giving off light', 'A2', ARRAY['adjectives'], ARRAY['Maya saw something shining on the floor.']),
('11111111-0005-0004-0001-000000000017', 'treasure', '/ˈtreʒər/', 'hazine', 'valuable things', 'A2', ARRAY['nouns'], ARRAY['It was an old treasure chest!']),
('11111111-0005-0004-0001-000000000018', 'chest', '/tʃest/', 'sandık', 'a large box', 'A2', ARRAY['nouns'], ARRAY['An old treasure chest covered in seashells.']),
('11111111-0005-0004-0001-000000000019', 'seashells', '/ˈsiːʃelz/', 'deniz kabukları', 'shells from the sea', 'A2', ARRAY['nouns', 'sea'], ARRAY['The chest was covered in seashells.']),
('11111111-0005-0004-0001-000000000020', 'seaweed', '/ˈsiːwiːd/', 'deniz yosunu', 'plants that grow in the sea', 'A2', ARRAY['nouns', 'sea'], ARRAY['Covered in seashells and seaweed!']),
('11111111-0005-0004-0001-000000000021', 'pearl', '/pɜːrl/', 'inci', 'a gem from oysters', 'A2', ARRAY['nouns'], ARRAY['A beautiful pearl necklace!']),
('11111111-0005-0004-0001-000000000022', 'necklace', '/ˈnekləs/', 'kolye', 'jewelry for the neck', 'A2', ARRAY['nouns'], ARRAY['A beautiful pearl necklace!']),
('11111111-0005-0004-0001-000000000023', 'map', '/mæp/', 'harita', 'a picture of an area', 'A1', ARRAY['nouns'], ARRAY['There was also an old map!']),
('11111111-0005-0004-0001-000000000024', 'explore', '/ɪkˈsplɔːr/', 'keşfetmek', 'to discover new places', 'A2', ARRAY['verbs'], ARRAY['They would explore every corner of the ocean!'])
ON CONFLICT (word, meaning_tr) DO NOTHING;

