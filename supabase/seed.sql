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
-- TEST USER (for development)
-- Email: test@demo.com / Password: Test1234
-- Student Number: 2024001
-- =============================================
INSERT INTO auth.users (
  id,
  instance_id,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  role,
  aud,
  confirmation_token
) VALUES (
  '88888888-0001-0001-0001-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'test@demo.com',
  crypt('Test1234', gen_salt('bf')),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  '{"first_name": "Test", "last_name": "Student", "student_number": "2024001", "school_code": "DEMO123"}',
  NOW(),
  NOW(),
  'authenticated',
  'authenticated',
  ''
);

-- Update profile for test user (trigger creates it, we just update with school info)
UPDATE profiles SET
  first_name = 'Test',
  last_name = 'Student',
  role = 'student',
  school_id = '33333333-0001-0001-0001-000000000001',
  class_id = '77777777-0001-0001-0001-000000000001',
  student_number = '2024001'
WHERE id = '88888888-0001-0001-0001-000000000001';

-- =============================================
-- BOOKS
-- =============================================
INSERT INTO books (id, title, slug, description, cover_url, level, genre, age_group, estimated_minutes, word_count, chapter_count, status, metadata, published_at) VALUES
('44444444-0001-0001-0001-000000000001', 'The Little Prince', 'the-little-prince', 'A young prince travels from planet to planet, learning about life, love, and friendship. A timeless classic that speaks to readers of all ages.', 'https://covers.openlibrary.org/b/id/8739161-L.jpg', 'A2', 'Fiction', 'elementary', 45, 3500, 3, 'published', '{"author": "Antoine de Saint-Exupéry", "year": 1943}', NOW()),
('44444444-0001-0001-0001-000000000002', 'Charlotte''s Web', 'charlottes-web', 'The story of a pig named Wilbur and his friendship with a barn spider named Charlotte. A tale about friendship and the circle of life.', 'https://covers.openlibrary.org/b/id/8406786-L.jpg', 'A2', 'Fiction', 'elementary', 60, 5200, 3, 'published', '{"author": "E.B. White", "year": 1952}', NOW()),
('44444444-0001-0001-0001-000000000003', 'The Secret Garden', 'the-secret-garden', 'A young orphan discovers a hidden garden and, with the help of new friends, brings it back to life while healing herself in the process.', 'https://covers.openlibrary.org/b/id/8231994-L.jpg', 'B1', 'Fiction', 'middle', 90, 8000, 3, 'published', '{"author": "Frances Hodgson Burnett", "year": 1911}', NOW()),
('44444444-0001-0001-0001-000000000004', 'Animal Farm', 'animal-farm', 'A group of farm animals rebel against their human farmer, hoping to create a society where animals can be equal and free.', 'https://covers.openlibrary.org/b/id/7984916-L.jpg', 'B2', 'Fiction', 'high', 120, 12000, 3, 'published', '{"author": "George Orwell", "year": 1945}', NOW()),
('44444444-0001-0001-0001-000000000005', 'The Cat in the Hat', 'the-cat-in-the-hat', 'Two children are visited by a mischievous cat who brings chaos and fun to their rainy day at home.', 'https://covers.openlibrary.org/b/id/8225261-L.jpg', 'A1', 'Fiction', 'elementary', 15, 800, 3, 'published', '{"author": "Dr. Seuss", "year": 1957}', NOW()),
('44444444-0001-0001-0001-000000000006', 'Wonder', 'wonder', 'August Pullman was born with a facial difference. This is his story about starting school and finding true friendship.', 'https://covers.openlibrary.org/b/id/8107708-L.jpg', 'B1', 'Fiction', 'middle', 150, 15000, 3, 'published', '{"author": "R.J. Palacio", "year": 2012}', NOW());

-- =============================================
-- CHAPTERS (The Little Prince)
-- =============================================
INSERT INTO chapters (id, book_id, title, order_index, content, word_count, estimated_minutes, vocabulary) VALUES
('55555555-0001-0001-0001-000000000001', '44444444-0001-0001-0001-000000000001', 'The Drawing', 1,
'Once when I was six years old I saw a magnificent picture in a book about the jungle. It showed a boa constrictor swallowing an animal.

I pondered deeply over the adventures of the jungle. And after some work with a colored pencil I succeeded in making my first drawing. My Drawing Number One. It looked like this: I showed my masterpiece to the grown-ups, and asked them whether the drawing frightened them.

But they answered: "Frighten? Why should anyone be frightened by a hat?"

My drawing was not a picture of a hat. It was a picture of a boa constrictor digesting an elephant. But since the grown-ups were not able to understand it, I made another drawing. My Drawing Number Two. The grown-ups'' response, this time, was to advise me to lay aside my drawings of boa constrictors, and devote myself instead to geography, history, arithmetic, and grammar.

That is why, at the age of six, I gave up what might have been a magnificent career as a painter.',
180, 5, '[{"word": "magnificent", "meaning": "muhteşem, görkemli", "phonetic": "/mæɡˈnɪfɪsənt/", "startIndex": 47, "endIndex": 58}, {"word": "boa constrictor", "meaning": "boa yılanı", "phonetic": "/ˈboʊə kənˈstrɪktər/", "startIndex": 102, "endIndex": 117}, {"word": "pondered", "meaning": "düşündü, kafa yordu", "phonetic": "/ˈpɒndərd/", "startIndex": 140, "endIndex": 148}, {"word": "masterpiece", "meaning": "başyapıt, şaheser", "phonetic": "/ˈmɑːstərpiːs/", "startIndex": 312, "endIndex": 323}]'),

('55555555-0001-0001-0001-000000000002', '44444444-0001-0001-0001-000000000001', 'The Pilot', 2,
'So then I chose another profession, and learned to pilot airplanes. I have flown a little over all parts of the world; and it is true that geography has been very useful to me.

At a glance I can distinguish China from Arizona. If one gets lost in the night, such knowledge is valuable.

In the course of this life I have had a great many encounters with a great many people who have been concerned with matters of consequence. I have lived a great deal among grown-ups. I have seen them intimately, close at hand. And that hasn''t much improved my opinion of them.

Whenever I met one of them who seemed to me at all clear-sighted, I tried the experiment of showing him my Drawing Number One, which I have always kept. I would try to find out if this was a person of true understanding. But, whoever it was, he or she would always say: "That is a hat."

Then I would never talk to that person about boa constrictors, or primeval forests, or stars. I would bring myself down to his level.',
200, 6, '[{"word": "profession", "meaning": "meslek", "phonetic": "/prəˈfeʃən/", "startIndex": 24, "endIndex": 34}, {"word": "distinguish", "meaning": "ayırt etmek", "phonetic": "/dɪˈstɪŋɡwɪʃ/", "startIndex": 197, "endIndex": 208}, {"word": "encounters", "meaning": "karşılaşmalar", "phonetic": "/ɪnˈkaʊntərz/", "startIndex": 320, "endIndex": 330}, {"word": "consequence", "meaning": "önem, sonuç", "phonetic": "/ˈkɒnsɪkwəns/", "startIndex": 392, "endIndex": 403}]'),

('55555555-0001-0001-0001-000000000003', '44444444-0001-0001-0001-000000000001', 'The Little Prince Arrives', 3,
'I lived my life alone, without anyone that I could really talk to, until I had an accident with my plane in the Desert of Sahara, six years ago. Something was broken in my engine.

And as I had with me neither a mechanic nor any passengers, I set myself to attempt the difficult repairs all alone. It was a question of life or death for me: I had scarcely enough drinking water to last a week.

The first night, then, I went to sleep on the sand, a thousand miles from any human habitation. I was more isolated than a shipwrecked sailor on a raft in the middle of the ocean.

Thus you can imagine my amazement, at sunrise, when I was awakened by an odd little voice. It said: "If you please, draw me a sheep!"

"What!"

"Draw me a sheep!"

I jumped to my feet, completely thunderstruck. I blinked my eyes hard. I looked carefully all around me. And I saw a most extraordinary small person, who stood there examining me with great seriousness.',
210, 7, '[{"word": "accident", "meaning": "kaza", "phonetic": "/ˈæksɪdənt/", "startIndex": 78, "endIndex": 86}, {"word": "scarcely", "meaning": "zar zor, güçlükle", "phonetic": "/ˈskeəsli/", "startIndex": 319, "endIndex": 327}, {"word": "habitation", "meaning": "yerleşim yeri", "phonetic": "/ˌhæbɪˈteɪʃən/", "startIndex": 467, "endIndex": 477}, {"word": "amazement", "meaning": "şaşkınlık, hayret", "phonetic": "/əˈmeɪzmənt/", "startIndex": 588, "endIndex": 597}, {"word": "thunderstruck", "meaning": "şaşkına dönmüş", "phonetic": "/ˈθʌndəstrʌk/", "startIndex": 756, "endIndex": 769}]');

-- =============================================
-- CHAPTERS (Charlotte's Web)
-- =============================================
INSERT INTO chapters (id, book_id, title, order_index, content, word_count, estimated_minutes, vocabulary) VALUES
('55555555-0001-0002-0001-000000000001', '44444444-0001-0001-0001-000000000002', 'Before Breakfast', 1,
'"Where''s Papa going with that ax?" said Fern to her mother as they were setting the table for breakfast.

"Out to the hoghouse," replied Mrs. Arable. "Some pigs were born last night."

"I don''t see why he needs an ax," continued Fern, who was only eight.

"Well," said her mother, "one of the pigs is a runt. It''s very small and weak, and it will never amount to anything. So your father has decided to do away with it."

"Do away with it?" shrieked Fern. "You mean kill it? Just because it''s smaller than the others?"

Mrs. Arable put a pitcher of cream on the table. "Don''t yell, Fern!" she said. "Your father is right. The pig would probably die anyway."

Fern pushed a chair out of the way and ran outdoors. The grass was wet and the earth smelled of springtime. Fern''s sneakers were sopping by the time she caught up with her father.',
180, 5, '[{"word": "ax", "meaning": "balta", "phonetic": "/æks/", "startIndex": 32, "endIndex": 34}, {"word": "hoghouse", "meaning": "domuz ahırı", "phonetic": "/ˈhɒɡhaʊs/", "startIndex": 95, "endIndex": 103}, {"word": "runt", "meaning": "sürünün en küçüğü", "phonetic": "/rʌnt/", "startIndex": 272, "endIndex": 276}, {"word": "shrieked", "meaning": "çığlık attı", "phonetic": "/ʃriːkt/", "startIndex": 402, "endIndex": 410}]'),

('55555555-0001-0002-0001-000000000002', '44444444-0001-0001-0001-000000000002', 'Wilbur', 2,
'Fern loved Wilbur more than anything. She loved to stroke him, to feed him, to put him to bed. Every morning, as soon as she got up, she warmed his milk, tied his bib on, and held the bottle for him.

Every afternoon, when the school bus stopped in front of her house, she jumped out and ran to the kitchen to fix another bottle for him. She fed him again at suppertime, and again just before going to bed.

Mrs. Arable gave him a bath every day in the kitchen sink. Each morning she tied a fresh ribbon on his tail.

Wilbur was what farmers call a spring pig, which simply means that he was born in springtime. When he was five weeks old, Mr. Arable said he was now big enough to sell, and would have to be sold.

Fern broke down and cried. But her father was firm about it. Wilbur''s appetite had increased; he was beginning to eat scraps of food in addition to milk. Mr. Arable was not willing to provide for him any longer.',
200, 6, '[{"word": "stroke", "meaning": "okşamak", "phonetic": "/stroʊk/", "startIndex": 55, "endIndex": 61}, {"word": "bib", "meaning": "önlük, mama önlüğü", "phonetic": "/bɪb/", "startIndex": 151, "endIndex": 154}, {"word": "ribbon", "meaning": "kurdele", "phonetic": "/ˈrɪbən/", "startIndex": 475, "endIndex": 481}, {"word": "appetite", "meaning": "iştah", "phonetic": "/ˈæpɪtaɪt/", "startIndex": 729, "endIndex": 737}]'),

('55555555-0001-0002-0001-000000000003', '44444444-0001-0001-0001-000000000002', 'Escape', 3,
'The barn was very large. It was very old. It smelled of hay and it smelled of manure. It smelled of the perspiration of tired horses and the wonderful sweet breath of patient cows.

It often had a sort of peaceful smell, as though nothing bad could happen ever again in the world. It smelled of grain and of harness dressing and of axle grease and of rubber boots and of new rope.

And whenever the cat was given a fish-head to eat, the barn would smell of fish. But mostly it smelled of hay, for there was always hay in the great loft up overhead. And there was always hay being pitched down to the cows and the horses and the sheep.

The barn was pleasantly warm in winter when the animals spent most of their time indoors, and it was pleasantly cool in summer when the big doors stood wide open to the breeze.',
180, 5, '[{"word": "barn", "meaning": "ahır, ambar", "phonetic": "/bɑːrn/", "startIndex": 4, "endIndex": 8}, {"word": "hay", "meaning": "saman", "phonetic": "/heɪ/", "startIndex": 54, "endIndex": 57}, {"word": "manure", "meaning": "gübre", "phonetic": "/məˈnjʊər/", "startIndex": 74, "endIndex": 80}, {"word": "perspiration", "meaning": "ter", "phonetic": "/ˌpɜːrspəˈreɪʃən/", "startIndex": 100, "endIndex": 112}]');

-- =============================================
-- CHAPTERS (The Secret Garden)
-- =============================================
INSERT INTO chapters (id, book_id, title, order_index, content, word_count, estimated_minutes, vocabulary) VALUES
('55555555-0001-0003-0001-000000000001', '44444444-0001-0001-0001-000000000003', 'There Is No One Left', 1,
'When Mary Lennox was sent to Misselthwaite Manor to live with her uncle everybody said she was the most disagreeable-looking child ever seen.

It was true, too. She had a little thin face and a little thin body, thin light hair and a sour expression. Her hair was yellow, and her face was yellow because she had been born in India and had always been ill in one way or another.

Her father had held a position under the English Government and had always been busy and ill himself, and her mother had been a great beauty who cared only to go to parties and amuse herself with gay people.

She had not wanted a little girl at all, and when Mary was born she handed her over to the care of an Ayah, who was made to understand that if she wished to please the Mem Sahib she must keep the child out of sight as much as possible.',
200, 7, '[{"word": "disagreeable", "meaning": "sevimsiz, nahoş", "phonetic": "/ˌdɪsəˈɡriːəbəl/", "startIndex": 89, "endIndex": 101}, {"word": "sour", "meaning": "ekşi, somurtkan", "phonetic": "/saʊər/", "startIndex": 209, "endIndex": 213}, {"word": "position", "meaning": "pozisyon, görev", "phonetic": "/pəˈzɪʃən/", "startIndex": 354, "endIndex": 362}, {"word": "amuse", "meaning": "eğlendirmek", "phonetic": "/əˈmjuːz/", "startIndex": 502, "endIndex": 507}]'),

('55555555-0001-0003-0001-000000000002', '44444444-0001-0001-0001-000000000003', 'Mistress Mary Quite Contrary', 2,
'Mary had liked to look at her mother from a distance and she had thought her very pretty, but as she knew very little of her she could scarcely have been expected to love her or to miss her very much when she was gone.

She did not miss her at all, in fact, and as she was a self-absorbed child she gave her entire thought to herself, as she had always done.

If she had been older she would no doubt have been very anxious at being left alone in the world, but she was very young, and as she had always been taken care of, she supposed she always would be.

What she thought was that she would like to know if she was going to nice people, who would be polite to her and give her her own way as her Ayah and the other native servants had done.',
180, 6, '[{"word": "distance", "meaning": "mesafe, uzaklık", "phonetic": "/ˈdɪstəns/", "startIndex": 40, "endIndex": 48}, {"word": "self-absorbed", "meaning": "bencil, kendine dönük", "phonetic": "/ˌselfəbˈzɔːrbd/", "startIndex": 273, "endIndex": 286}, {"word": "anxious", "meaning": "endişeli, kaygılı", "phonetic": "/ˈæŋkʃəs/", "startIndex": 411, "endIndex": 418}, {"word": "polite", "meaning": "kibar, nazik", "phonetic": "/pəˈlaɪt/", "startIndex": 621, "endIndex": 627}]'),

('55555555-0001-0003-0001-000000000003', '44444444-0001-0001-0001-000000000003', 'Across the Moor', 3,
'She slept a long time, and when she awakened Mrs. Medlock had bought a lunch-basket at one of the stations and they had some chicken and cold beef and bread and butter and some hot tea.

The rain seemed to be streaming down more heavily than ever and everybody in the station wore wet and glistening waterproofs. The guard lighted the lamps in the carriage, and Mrs. Medlock cheered up very much over her tea and chicken and beef.

She ate a great deal and afterward fell asleep herself, and Mary sat and stared at her and watched her fine bonnet slip on one side until she herself fell asleep once more in the corner of the carriage, lulled by the splashing of the rain against the windows.

It was quite dark when she awakened again. The train had stopped at a station and Mrs. Medlock was shaking her.',
190, 6, '[{"word": "awakened", "meaning": "uyandı", "phonetic": "/əˈweɪkənd/", "startIndex": 31, "endIndex": 39}, {"word": "glistening", "meaning": "parıldayan", "phonetic": "/ˈɡlɪsənɪŋ/", "startIndex": 262, "endIndex": 272}, {"word": "carriage", "meaning": "vagon, araba", "phonetic": "/ˈkærɪdʒ/", "startIndex": 329, "endIndex": 337}, {"word": "lulled", "meaning": "yatıştırılmış", "phonetic": "/lʌld/", "startIndex": 581, "endIndex": 587}]');

-- =============================================
-- INLINE ACTIVITIES (for The Little Prince chapters)
-- =============================================
INSERT INTO inline_activities (id, chapter_id, type, after_paragraph_index, content, xp_reward, vocabulary_words) VALUES
-- Chapter 1: The Drawing
('66666666-0001-0001-0001-000000000001', '55555555-0001-0001-0001-000000000001', 'true_false', 0,
'{"statement": "The narrator saw the picture in a newspaper.", "correctAnswer": false}', 5, ARRAY[]::TEXT[]),
('66666666-0001-0001-0001-000000000002', '55555555-0001-0001-0001-000000000001', 'word_translation', 1,
'{"word": "magnificent", "correctAnswer": "muhteşem", "options": ["muhteşem", "korkunç", "sıradan"]}', 5, ARRAY['magnificent']),
('66666666-0001-0001-0001-000000000003', '55555555-0001-0001-0001-000000000001', 'true_false', 2,
'{"statement": "The grown-ups thought the drawing was a hat.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0001-0001-0001-000000000004', '55555555-0001-0001-0001-000000000001', 'find_words', 3,
'{"instruction": "Find two subjects the grown-ups suggested.", "options": ["Geography", "Music", "Arithmetic"], "correctAnswers": ["Geography", "Arithmetic"]}', 5, ARRAY['geography', 'arithmetic']),

-- Chapter 2: The Pilot
('66666666-0001-0002-0001-000000000001', '55555555-0001-0001-0001-000000000002', 'true_false', 0,
'{"statement": "The narrator chose to become a pilot.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0001-0002-0001-000000000002', '55555555-0001-0001-0001-000000000002', 'word_translation', 1,
'{"word": "distinguish", "correctAnswer": "ayırt etmek", "options": ["ayırt etmek", "uçmak", "kaybolmak"]}', 5, ARRAY['distinguish']),

-- Chapter 3: The Little Prince Arrives
('66666666-0001-0003-0001-000000000001', '55555555-0001-0001-0001-000000000003', 'true_false', 0,
'{"statement": "The narrator''s plane crashed in the Sahara Desert.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]),
('66666666-0001-0003-0001-000000000002', '55555555-0001-0001-0001-000000000003', 'word_translation', 1,
'{"word": "scarcely", "correctAnswer": "zar zor", "options": ["zar zor", "bolca", "hızlıca"]}', 5, ARRAY['scarcely']),
('66666666-0001-0003-0001-000000000003', '55555555-0001-0001-0001-000000000003', 'true_false', 4,
'{"statement": "The little voice asked for a drawing of a sheep.", "correctAnswer": true}', 5, ARRAY[]::TEXT[]);
