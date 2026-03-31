-- =============================================
-- LEAGUE MATCHMAKING REDESIGN — Part 1
-- Tables, helper functions, and bot profile seed
-- =============================================

-- =============================================
-- Part 1a: bot_profiles table
-- =============================================
CREATE TABLE IF NOT EXISTS bot_profiles (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR NOT NULL,
    last_name VARCHAR NOT NULL,
    avatar_equipped_cache JSONB,
    school_name VARCHAR NOT NULL
);

-- =============================================
-- Part 1b: league_groups table
-- =============================================
CREATE TABLE IF NOT EXISTS league_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    week_start DATE NOT NULL,
    tier VARCHAR(20) NOT NULL,
    xp_bucket INTEGER NOT NULL DEFAULT 0,
    member_count INTEGER NOT NULL DEFAULT 0,
    processed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_league_groups_week_tier_bucket ON league_groups(week_start, tier, xp_bucket);
CREATE INDEX idx_league_groups_unprocessed ON league_groups(week_start) WHERE processed = false;

-- =============================================
-- Part 1c: league_group_members table
-- =============================================
CREATE TABLE IF NOT EXISTS league_group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES league_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    school_id UUID,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, week_start)
);

CREATE INDEX idx_league_group_members_user_week ON league_group_members(user_id, week_start);
CREATE INDEX idx_league_group_members_group ON league_group_members(group_id);
CREATE INDEX idx_league_group_members_group_user ON league_group_members(group_id, user_id);

-- =============================================
-- Part 1d: RLS
-- =============================================
ALTER TABLE league_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE league_group_members ENABLE ROW LEVEL SECURITY;

-- =============================================
-- Part 1e: Add group_id to league_history + handle CHECK constraint
-- =============================================
ALTER TABLE league_history ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES league_groups(id) ON DELETE SET NULL;

DO $$ BEGIN
  ALTER TABLE league_history DROP CONSTRAINT IF EXISTS league_history_result_check;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- =============================================
-- Part 1f: Bot XP helper functions
-- =============================================
CREATE OR REPLACE FUNCTION bot_weekly_xp_target(
    p_group_id UUID,
    p_slot INTEGER,
    p_xp_bucket INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_seed INTEGER := abs(hashtext(p_group_id::text || '_' || p_slot::text));
    v_min INTEGER;
    v_max INTEGER;
BEGIN
    CASE p_xp_bucket
        WHEN 0 THEN v_min := 20;  v_max := 80;
        WHEN 1 THEN v_min := 30;  v_max := 99;
        WHEN 2 THEN v_min := 100; v_max := 299;
        WHEN 3 THEN v_min := 300; v_max := 599;
        WHEN 4 THEN v_min := 600; v_max := 1000;
        ELSE         v_min := 20;  v_max := 80;
    END CASE;
    RETURN v_min + (v_seed % (v_max - v_min + 1));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION bot_current_xp(
    p_group_id UUID,
    p_slot INTEGER,
    p_xp_bucket INTEGER,
    p_week_start DATE
) RETURNS INTEGER AS $$
DECLARE
    v_target INTEGER := bot_weekly_xp_target(p_group_id, p_slot, p_xp_bucket);
    v_elapsed FLOAT := EXTRACT(EPOCH FROM (app_now() - p_week_start::timestamptz)) / (7.0 * 86400);
    v_day_seed INTEGER := abs(hashtext(p_group_id::text || '_' || p_slot::text || '_' || EXTRACT(DOW FROM app_now())::text));
    v_jitter FLOAT := (v_day_seed % 20 - 10) / 100.0;
BEGIN
    v_elapsed := GREATEST(0, LEAST(1, v_elapsed));
    RETURN LEAST(v_target, GREATEST(0, (v_target * (v_elapsed + v_jitter))::INTEGER));
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================
-- Part 1g: Seed bot_profiles (~200 entries)
-- =============================================
INSERT INTO bot_profiles (first_name, last_name, avatar_equipped_cache, school_name) VALUES
-- 1-10
('Emre', 'Yıldız', '{"base_url": "animals/fox.png", "layers": []}', 'Atatürk İlkokulu'),
('Zeynep', 'Kaya', '{"base_url": "animals/cat.png", "layers": []}', 'Cumhuriyet Ortaokulu'),
('Mehmet', 'Demir', '{"base_url": "animals/bear.png", "layers": []}', 'Fatih İlkokulu'),
('Elif', 'Çelik', '{"base_url": "animals/rabbit.png", "layers": []}', 'Mimar Sinan Ortaokulu'),
('Ahmet', 'Şahin', '{"base_url": "animals/owl.png", "layers": []}', 'İnönü İlkokulu'),
('Defne', 'Arslan', '{"base_url": "animals/penguin.png", "layers": []}', 'Mehmet Akif Ersoy İlkokulu'),
('Can', 'Özdemir', '{"base_url": "animals/dog.png", "layers": []}', 'Yunus Emre Ortaokulu'),
('Selin', 'Aydın', '{"base_url": "animals/panda.png", "layers": []}', 'Namık Kemal İlkokulu'),
('Burak', 'Koç', '{"base_url": "animals/lion.png", "layers": []}', 'Hasan Ali Yücel Ortaokulu'),
('Ela', 'Yılmaz', '{"base_url": "animals/koala.png", "layers": []}', 'Gazi İlkokulu'),
-- 11-20
('Mert', 'Aktaş', '{"base_url": "animals/elephant.png", "layers": []}', 'Ziya Gökalp Ortaokulu'),
('Nehir', 'Polat', '{"base_url": "animals/giraffe.png", "layers": []}', 'Barbaros Hayrettin İlkokulu'),
('Efe', 'Kurt', '{"base_url": "animals/monkey.png", "layers": []}', 'Şehit Öğretmen İlkokulu'),
('Ecrin', 'Öztürk', '{"base_url": "animals/dolphin.png", "layers": []}', 'Atatürk Ortaokulu'),
('Kerem', 'Aksoy', '{"base_url": "animals/tiger.png", "layers": []}', 'Kanuni Sultan Süleyman İlkokulu'),
('Yaren', 'Doğan', '{"base_url": "animals/wolf.png", "layers": []}', 'Turgut Özal Ortaokulu'),
('Baran', 'Erdoğan', '{"base_url": "animals/deer.png", "layers": []}', 'Necmettin Erbakan İlkokulu'),
('Lina', 'Güneş', '{"base_url": "animals/horse.png", "layers": []}', 'Adnan Menderes Ortaokulu'),
('Yusuf', 'Karaca', '{"base_url": "animals/parrot.png", "layers": []}', 'İstiklal İlkokulu'),
('Mira', 'Tunç', '{"base_url": "animals/turtle.png", "layers": []}', 'Kazım Karabekir Ortaokulu'),
-- 21-30
('Ali', 'Acar', '{"base_url": "animals/fox.png", "layers": []}', 'Kurtuluş İlkokulu'),
('Ada', 'Albayrak', '{"base_url": "animals/cat.png", "layers": []}', 'Osmangazi Ortaokulu'),
('Kaan', 'Korkmaz', '{"base_url": "animals/bear.png", "layers": []}', '23 Nisan İlkokulu'),
('Asya', 'Sezer', '{"base_url": "animals/rabbit.png", "layers": []}', 'Alparslan Ortaokulu'),
('Arda', 'Uysal', '{"base_url": "animals/owl.png", "layers": []}', 'Selçuklu İlkokulu'),
('Duru', 'Yavuz', '{"base_url": "animals/penguin.png", "layers": []}', 'Ertuğrul Gazi Ortaokulu'),
('Emir', 'Bal', '{"base_url": "animals/dog.png", "layers": []}', 'Malazgirt İlkokulu'),
('Azra', 'Taş', '{"base_url": "animals/panda.png", "layers": []}', 'Mevlana İlkokulu'),
('Deniz', 'Coşkun', '{"base_url": "animals/lion.png", "layers": []}', 'Sakarya Ortaokulu'),
('İrem', 'Kılıç', '{"base_url": "animals/koala.png", "layers": []}', 'Zafer İlkokulu'),
-- 31-40
('Berk', 'Yıldız', '{"base_url": "animals/elephant.png", "layers": []}', 'Atatürk İlkokulu'),
('Melis', 'Kaya', '{"base_url": "animals/giraffe.png", "layers": []}', 'Cumhuriyet Ortaokulu'),
('Onur', 'Demir', '{"base_url": "animals/monkey.png", "layers": []}', 'Fatih İlkokulu'),
('Ceren', 'Çelik', '{"base_url": "animals/dolphin.png", "layers": []}', 'Mimar Sinan Ortaokulu'),
('Oğuz', 'Şahin', '{"base_url": "animals/tiger.png", "layers": []}', 'İnönü İlkokulu'),
('Büşra', 'Arslan', '{"base_url": "animals/wolf.png", "layers": []}', 'Mehmet Akif Ersoy İlkokulu'),
('Serkan', 'Özdemir', '{"base_url": "animals/deer.png", "layers": []}', 'Yunus Emre Ortaokulu'),
('Pelin', 'Aydın', '{"base_url": "animals/horse.png", "layers": []}', 'Namık Kemal İlkokulu'),
('Tolga', 'Koç', '{"base_url": "animals/parrot.png", "layers": []}', 'Hasan Ali Yücel Ortaokulu'),
('Cansu', 'Yılmaz', '{"base_url": "animals/turtle.png", "layers": []}', 'Gazi İlkokulu'),
-- 41-50
('Cem', 'Aktaş', '{"base_url": "animals/fox.png", "layers": []}', 'Ziya Gökalp Ortaokulu'),
('Ebru', 'Polat', '{"base_url": "animals/cat.png", "layers": []}', 'Barbaros Hayrettin İlkokulu'),
('Eren', 'Kurt', '{"base_url": "animals/bear.png", "layers": []}', 'Şehit Öğretmen İlkokulu'),
('Gizem', 'Öztürk', '{"base_url": "animals/rabbit.png", "layers": []}', 'Atatürk Ortaokulu'),
('Alp', 'Aksoy', '{"base_url": "animals/owl.png", "layers": []}', 'Kanuni Sultan Süleyman İlkokulu'),
('Hande', 'Doğan', '{"base_url": "animals/penguin.png", "layers": []}', 'Turgut Özal Ortaokulu'),
('Umut', 'Erdoğan', '{"base_url": "animals/dog.png", "layers": []}', 'Necmettin Erbakan İlkokulu'),
('İpek', 'Güneş', '{"base_url": "animals/panda.png", "layers": []}', 'Adnan Menderes Ortaokulu'),
('Barış', 'Karaca', '{"base_url": "animals/lion.png", "layers": []}', 'İstiklal İlkokulu'),
('Naz', 'Tunç', '{"base_url": "animals/koala.png", "layers": []}', 'Kazım Karabekir Ortaokulu'),
-- 51-60
('Tuna', 'Acar', '{"base_url": "animals/elephant.png", "layers": []}', 'Kurtuluş İlkokulu'),
('Sude', 'Albayrak', '{"base_url": "animals/giraffe.png", "layers": []}', 'Osmangazi Ortaokulu'),
('Doruk', 'Korkmaz', '{"base_url": "animals/monkey.png", "layers": []}', 'Beşiktaş İlkokulu'),
('Şeyma', 'Sezer', '{"base_url": "animals/dolphin.png", "layers": []}', 'Alparslan Ortaokulu'),
('Eymen', 'Uysal', '{"base_url": "animals/tiger.png", "layers": []}', 'Selçuklu İlkokulu'),
('Bengisu', 'Yavuz', '{"base_url": "animals/wolf.png", "layers": []}', 'Ertuğrul Gazi Ortaokulu'),
('Alperen', 'Bal', '{"base_url": "animals/deer.png", "layers": []}', 'Malazgirt İlkokulu'),
('Buse', 'Taş', '{"base_url": "animals/horse.png", "layers": []}', 'Mevlana İlkokulu'),
('Ömer', 'Coşkun', '{"base_url": "animals/parrot.png", "layers": []}', 'Sakarya Ortaokulu'),
('Defne', 'Kılıç', '{"base_url": "animals/turtle.png", "layers": []}', 'Zafer İlkokulu'),
-- 61-70
('Emre', 'Polat', '{"base_url": "animals/fox.png", "layers": []}', '23 Nisan İlkokulu'),
('Zeynep', 'Kurt', '{"base_url": "animals/cat.png", "layers": []}', 'Barbaros Hayrettin İlkokulu'),
('Mehmet', 'Aksoy', '{"base_url": "animals/bear.png", "layers": []}', 'Gazi İlkokulu'),
('Elif', 'Doğan', '{"base_url": "animals/rabbit.png", "layers": []}', 'Turgut Özal Ortaokulu'),
('Ahmet', 'Güneş', '{"base_url": "animals/owl.png", "layers": []}', 'İstiklal İlkokulu'),
('Selin', 'Karaca', '{"base_url": "animals/penguin.png", "layers": []}', 'Cumhuriyet Ortaokulu'),
('Can', 'Tunç', '{"base_url": "animals/dog.png", "layers": []}', 'Fatih İlkokulu'),
('Ela', 'Acar', '{"base_url": "animals/panda.png", "layers": []}', 'Mimar Sinan Ortaokulu'),
('Mert', 'Albayrak', '{"base_url": "animals/lion.png", "layers": []}', 'İnönü İlkokulu'),
('Nehir', 'Korkmaz', '{"base_url": "animals/koala.png", "layers": []}', 'Mehmet Akif Ersoy İlkokulu'),
-- 71-80
('Efe', 'Sezer', '{"base_url": "animals/elephant.png", "layers": []}', 'Yunus Emre Ortaokulu'),
('Ecrin', 'Uysal', '{"base_url": "animals/giraffe.png", "layers": []}', 'Namık Kemal İlkokulu'),
('Kerem', 'Yavuz', '{"base_url": "animals/monkey.png", "layers": []}', 'Hasan Ali Yücel Ortaokulu'),
('Yaren', 'Bal', '{"base_url": "animals/dolphin.png", "layers": []}', 'Atatürk İlkokulu'),
('Baran', 'Taş', '{"base_url": "animals/tiger.png", "layers": []}', 'Ziya Gökalp Ortaokulu'),
('Lina', 'Coşkun', '{"base_url": "animals/wolf.png", "layers": []}', 'Şehit Öğretmen İlkokulu'),
('Yusuf', 'Kılıç', '{"base_url": "animals/deer.png", "layers": []}', 'Atatürk Ortaokulu'),
('Mira', 'Yıldız', '{"base_url": "animals/horse.png", "layers": []}', 'Kanuni Sultan Süleyman İlkokulu'),
('Ali', 'Kaya', '{"base_url": "animals/parrot.png", "layers": []}', 'Necmettin Erbakan İlkokulu'),
('Ada', 'Demir', '{"base_url": "animals/turtle.png", "layers": []}', 'Adnan Menderes Ortaokulu'),
-- 81-90
('Kaan', 'Çelik', '{"base_url": "animals/fox.png", "layers": []}', 'Kazım Karabekir Ortaokulu'),
('Asya', 'Şahin', '{"base_url": "animals/cat.png", "layers": []}', 'Kurtuluş İlkokulu'),
('Arda', 'Arslan', '{"base_url": "animals/bear.png", "layers": []}', 'Osmangazi Ortaokulu'),
('Duru', 'Özdemir', '{"base_url": "animals/rabbit.png", "layers": []}', 'Beşiktaş İlkokulu'),
('Emir', 'Aydın', '{"base_url": "animals/owl.png", "layers": []}', 'Alparslan Ortaokulu'),
('Azra', 'Koç', '{"base_url": "animals/penguin.png", "layers": []}', 'Selçuklu İlkokulu'),
('Deniz', 'Yılmaz', '{"base_url": "animals/dog.png", "layers": []}', 'Ertuğrul Gazi Ortaokulu'),
('İrem', 'Aktaş', '{"base_url": "animals/panda.png", "layers": []}', 'Malazgirt İlkokulu'),
('Berk', 'Polat', '{"base_url": "animals/lion.png", "layers": []}', 'Mevlana İlkokulu'),
('Melis', 'Kurt', '{"base_url": "animals/koala.png", "layers": []}', 'Sakarya Ortaokulu'),
-- 91-100
('Onur', 'Öztürk', '{"base_url": "animals/elephant.png", "layers": []}', 'Zafer İlkokulu'),
('Ceren', 'Aksoy', '{"base_url": "animals/giraffe.png", "layers": []}', '23 Nisan İlkokulu'),
('Oğuz', 'Doğan', '{"base_url": "animals/monkey.png", "layers": []}', 'Atatürk İlkokulu'),
('Büşra', 'Erdoğan', '{"base_url": "animals/dolphin.png", "layers": []}', 'Cumhuriyet Ortaokulu'),
('Serkan', 'Güneş', '{"base_url": "animals/tiger.png", "layers": []}', 'Fatih İlkokulu'),
('Pelin', 'Karaca', '{"base_url": "animals/wolf.png", "layers": []}', 'Mimar Sinan Ortaokulu'),
('Tolga', 'Tunç', '{"base_url": "animals/deer.png", "layers": []}', 'İnönü İlkokulu'),
('Cansu', 'Acar', '{"base_url": "animals/horse.png", "layers": []}', 'Mehmet Akif Ersoy İlkokulu'),
('Cem', 'Albayrak', '{"base_url": "animals/parrot.png", "layers": []}', 'Yunus Emre Ortaokulu'),
('Ebru', 'Korkmaz', '{"base_url": "animals/turtle.png", "layers": []}', 'Namık Kemal İlkokulu'),
-- 101-110
('Eren', 'Sezer', '{"base_url": "animals/fox.png", "layers": []}', 'Hasan Ali Yücel Ortaokulu'),
('Gizem', 'Uysal', '{"base_url": "animals/cat.png", "layers": []}', 'Gazi İlkokulu'),
('Alp', 'Yavuz', '{"base_url": "animals/bear.png", "layers": []}', 'Ziya Gökalp Ortaokulu'),
('Hande', 'Bal', '{"base_url": "animals/rabbit.png", "layers": []}', 'Barbaros Hayrettin İlkokulu'),
('Umut', 'Taş', '{"base_url": "animals/owl.png", "layers": []}', 'Şehit Öğretmen İlkokulu'),
('İpek', 'Coşkun', '{"base_url": "animals/penguin.png", "layers": []}', 'Atatürk Ortaokulu'),
('Barış', 'Kılıç', '{"base_url": "animals/dog.png", "layers": []}', 'Kanuni Sultan Süleyman İlkokulu'),
('Naz', 'Yıldız', '{"base_url": "animals/panda.png", "layers": []}', 'Turgut Özal Ortaokulu'),
('Tuna', 'Kaya', '{"base_url": "animals/lion.png", "layers": []}', 'Necmettin Erbakan İlkokulu'),
('Sude', 'Demir', '{"base_url": "animals/koala.png", "layers": []}', 'Adnan Menderes Ortaokulu'),
-- 111-120
('Doruk', 'Çelik', '{"base_url": "animals/elephant.png", "layers": []}', 'İstiklal İlkokulu'),
('Şeyma', 'Şahin', '{"base_url": "animals/giraffe.png", "layers": []}', 'Kazım Karabekir Ortaokulu'),
('Eymen', 'Arslan', '{"base_url": "animals/monkey.png", "layers": []}', 'Kurtuluş İlkokulu'),
('Bengisu', 'Özdemir', '{"base_url": "animals/dolphin.png", "layers": []}', 'Osmangazi Ortaokulu'),
('Alperen', 'Aydın', '{"base_url": "animals/tiger.png", "layers": []}', 'Beşiktaş İlkokulu'),
('Buse', 'Koç', '{"base_url": "animals/wolf.png", "layers": []}', 'Alparslan Ortaokulu'),
('Ömer', 'Yılmaz', '{"base_url": "animals/deer.png", "layers": []}', 'Selçuklu İlkokulu'),
('Emre', 'Aktaş', '{"base_url": "animals/horse.png", "layers": []}', 'Ertuğrul Gazi Ortaokulu'),
('Zeynep', 'Polat', '{"base_url": "animals/parrot.png", "layers": []}', 'Malazgirt İlkokulu'),
('Mehmet', 'Kurt', '{"base_url": "animals/turtle.png", "layers": []}', 'Mevlana İlkokulu'),
-- 121-130
('Elif', 'Öztürk', '{"base_url": "animals/fox.png", "layers": []}', 'Sakarya Ortaokulu'),
('Ahmet', 'Aksoy', '{"base_url": "animals/cat.png", "layers": []}', 'Zafer İlkokulu'),
('Defne', 'Doğan', '{"base_url": "animals/bear.png", "layers": []}', '23 Nisan İlkokulu'),
('Can', 'Erdoğan', '{"base_url": "animals/rabbit.png", "layers": []}', 'Atatürk İlkokulu'),
('Selin', 'Güneş', '{"base_url": "animals/owl.png", "layers": []}', 'Cumhuriyet Ortaokulu'),
('Ela', 'Karaca', '{"base_url": "animals/penguin.png", "layers": []}', 'Fatih İlkokulu'),
('Mert', 'Tunç', '{"base_url": "animals/dog.png", "layers": []}', 'Mimar Sinan Ortaokulu'),
('Nehir', 'Acar', '{"base_url": "animals/panda.png", "layers": []}', 'İnönü İlkokulu'),
('Efe', 'Albayrak', '{"base_url": "animals/lion.png", "layers": []}', 'Mehmet Akif Ersoy İlkokulu'),
('Ecrin', 'Korkmaz', '{"base_url": "animals/koala.png", "layers": []}', 'Yunus Emre Ortaokulu'),
-- 131-140
('Kerem', 'Sezer', '{"base_url": "animals/elephant.png", "layers": []}', 'Namık Kemal İlkokulu'),
('Yaren', 'Uysal', '{"base_url": "animals/giraffe.png", "layers": []}', 'Hasan Ali Yücel Ortaokulu'),
('Baran', 'Yavuz', '{"base_url": "animals/monkey.png", "layers": []}', 'Gazi İlkokulu'),
('Lina', 'Bal', '{"base_url": "animals/dolphin.png", "layers": []}', 'Ziya Gökalp Ortaokulu'),
('Yusuf', 'Taş', '{"base_url": "animals/tiger.png", "layers": []}', 'Barbaros Hayrettin İlkokulu'),
('Mira', 'Coşkun', '{"base_url": "animals/wolf.png", "layers": []}', 'Şehit Öğretmen İlkokulu'),
('Ali', 'Kılıç', '{"base_url": "animals/deer.png", "layers": []}', 'Atatürk Ortaokulu'),
('Ada', 'Yıldız', '{"base_url": "animals/horse.png", "layers": []}', 'Kanuni Sultan Süleyman İlkokulu'),
('Kaan', 'Kaya', '{"base_url": "animals/parrot.png", "layers": []}', 'Turgut Özal Ortaokulu'),
('Asya', 'Demir', '{"base_url": "animals/turtle.png", "layers": []}', 'Necmettin Erbakan İlkokulu'),
-- 141-150
('Arda', 'Çelik', '{"base_url": "animals/fox.png", "layers": []}', 'Adnan Menderes Ortaokulu'),
('Duru', 'Şahin', '{"base_url": "animals/cat.png", "layers": []}', 'İstiklal İlkokulu'),
('Emir', 'Arslan', '{"base_url": "animals/bear.png", "layers": []}', 'Kazım Karabekir Ortaokulu'),
('Azra', 'Özdemir', '{"base_url": "animals/rabbit.png", "layers": []}', 'Kurtuluş İlkokulu'),
('Deniz', 'Aydın', '{"base_url": "animals/owl.png", "layers": []}', 'Osmangazi Ortaokulu'),
('İrem', 'Koç', '{"base_url": "animals/penguin.png", "layers": []}', 'Beşiktaş İlkokulu'),
('Berk', 'Yılmaz', '{"base_url": "animals/dog.png", "layers": []}', 'Alparslan Ortaokulu'),
('Melis', 'Aktaş', '{"base_url": "animals/panda.png", "layers": []}', 'Selçuklu İlkokulu'),
('Onur', 'Polat', '{"base_url": "animals/lion.png", "layers": []}', 'Ertuğrul Gazi Ortaokulu'),
('Ceren', 'Kurt', '{"base_url": "animals/koala.png", "layers": []}', 'Malazgirt İlkokulu'),
-- 151-160
('Oğuz', 'Öztürk', '{"base_url": "animals/elephant.png", "layers": []}', 'Mevlana İlkokulu'),
('Büşra', 'Aksoy', '{"base_url": "animals/giraffe.png", "layers": []}', 'Sakarya Ortaokulu'),
('Serkan', 'Doğan', '{"base_url": "animals/monkey.png", "layers": []}', 'Zafer İlkokulu'),
('Pelin', 'Erdoğan', '{"base_url": "animals/dolphin.png", "layers": []}', '23 Nisan İlkokulu'),
('Tolga', 'Güneş', '{"base_url": "animals/tiger.png", "layers": []}', 'Atatürk İlkokulu'),
('Cansu', 'Karaca', '{"base_url": "animals/wolf.png", "layers": []}', 'Cumhuriyet Ortaokulu'),
('Cem', 'Tunç', '{"base_url": "animals/deer.png", "layers": []}', 'Fatih İlkokulu'),
('Ebru', 'Acar', '{"base_url": "animals/horse.png", "layers": []}', 'Mimar Sinan Ortaokulu'),
('Eren', 'Albayrak', '{"base_url": "animals/parrot.png", "layers": []}', 'İnönü İlkokulu'),
('Gizem', 'Korkmaz', '{"base_url": "animals/turtle.png", "layers": []}', 'Mehmet Akif Ersoy İlkokulu'),
-- 161-170
('Alp', 'Sezer', '{"base_url": "animals/fox.png", "layers": []}', 'Yunus Emre Ortaokulu'),
('Hande', 'Uysal', '{"base_url": "animals/cat.png", "layers": []}', 'Namık Kemal İlkokulu'),
('Umut', 'Yavuz', '{"base_url": "animals/bear.png", "layers": []}', 'Hasan Ali Yücel Ortaokulu'),
('İpek', 'Bal', '{"base_url": "animals/rabbit.png", "layers": []}', 'Gazi İlkokulu'),
('Barış', 'Taş', '{"base_url": "animals/owl.png", "layers": []}', 'Ziya Gökalp Ortaokulu'),
('Naz', 'Coşkun', '{"base_url": "animals/penguin.png", "layers": []}', 'Barbaros Hayrettin İlkokulu'),
('Tuna', 'Kılıç', '{"base_url": "animals/dog.png", "layers": []}', 'Şehit Öğretmen İlkokulu'),
('Sude', 'Yıldız', '{"base_url": "animals/panda.png", "layers": []}', 'Atatürk Ortaokulu'),
('Doruk', 'Kaya', '{"base_url": "animals/lion.png", "layers": []}', 'Kanuni Sultan Süleyman İlkokulu'),
('Şeyma', 'Demir', '{"base_url": "animals/koala.png", "layers": []}', 'Turgut Özal Ortaokulu'),
-- 171-180
('Eymen', 'Çelik', '{"base_url": "animals/elephant.png", "layers": []}', 'Necmettin Erbakan İlkokulu'),
('Bengisu', 'Şahin', '{"base_url": "animals/giraffe.png", "layers": []}', 'Adnan Menderes Ortaokulu'),
('Alperen', 'Arslan', '{"base_url": "animals/monkey.png", "layers": []}', 'İstiklal İlkokulu'),
('Buse', 'Özdemir', '{"base_url": "animals/dolphin.png", "layers": []}', 'Kazım Karabekir Ortaokulu'),
('Ömer', 'Aydın', '{"base_url": "animals/tiger.png", "layers": []}', 'Kurtuluş İlkokulu'),
('Emre', 'Koç', '{"base_url": "animals/wolf.png", "layers": []}', 'Osmangazi Ortaokulu'),
('Zeynep', 'Yılmaz', '{"base_url": "animals/deer.png", "layers": []}', 'Beşiktaş İlkokulu'),
('Mehmet', 'Aktaş', '{"base_url": "animals/horse.png", "layers": []}', 'Alparslan Ortaokulu'),
('Elif', 'Polat', '{"base_url": "animals/parrot.png", "layers": []}', 'Selçuklu İlkokulu'),
('Ahmet', 'Kurt', '{"base_url": "animals/turtle.png", "layers": []}', 'Ertuğrul Gazi Ortaokulu'),
-- 181-190
('Defne', 'Öztürk', '{"base_url": "animals/fox.png", "layers": []}', 'Malazgirt İlkokulu'),
('Can', 'Aksoy', '{"base_url": "animals/cat.png", "layers": []}', 'Mevlana İlkokulu'),
('Selin', 'Doğan', '{"base_url": "animals/bear.png", "layers": []}', 'Sakarya Ortaokulu'),
('Ela', 'Erdoğan', '{"base_url": "animals/rabbit.png", "layers": []}', 'Zafer İlkokulu'),
('Mert', 'Güneş', '{"base_url": "animals/owl.png", "layers": []}', '23 Nisan İlkokulu'),
('Nehir', 'Karaca', '{"base_url": "animals/penguin.png", "layers": []}', 'Atatürk İlkokulu'),
('Efe', 'Tunç', '{"base_url": "animals/dog.png", "layers": []}', 'Cumhuriyet Ortaokulu'),
('Ecrin', 'Acar', '{"base_url": "animals/panda.png", "layers": []}', 'Fatih İlkokulu'),
('Kerem', 'Albayrak', '{"base_url": "animals/lion.png", "layers": []}', 'Mimar Sinan Ortaokulu'),
('Yaren', 'Korkmaz', '{"base_url": "animals/koala.png", "layers": []}', 'İnönü İlkokulu'),
-- 191-200
('Baran', 'Sezer', '{"base_url": "animals/elephant.png", "layers": []}', 'Mehmet Akif Ersoy İlkokulu'),
('Lina', 'Uysal', '{"base_url": "animals/giraffe.png", "layers": []}', 'Yunus Emre Ortaokulu'),
('Yusuf', 'Yavuz', '{"base_url": "animals/monkey.png", "layers": []}', 'Namık Kemal İlkokulu'),
('Mira', 'Bal', '{"base_url": "animals/dolphin.png", "layers": []}', 'Hasan Ali Yücel Ortaokulu'),
('Ali', 'Taş', '{"base_url": "animals/tiger.png", "layers": []}', 'Gazi İlkokulu'),
('Ada', 'Coşkun', '{"base_url": "animals/wolf.png", "layers": []}', 'Ziya Gökalp Ortaokulu'),
('Kaan', 'Kılıç', '{"base_url": "animals/deer.png", "layers": []}', 'Barbaros Hayrettin İlkokulu'),
('Asya', 'Yıldız', '{"base_url": "animals/horse.png", "layers": []}', 'Şehit Öğretmen İlkokulu'),
('Arda', 'Kaya', '{"base_url": "animals/parrot.png", "layers": []}', 'Atatürk Ortaokulu'),
('Duru', 'Demir', '{"base_url": "animals/turtle.png", "layers": []}', 'Kanuni Sultan Süleyman İlkokulu');

-- =============================================
-- Part 2: join_weekly_league RPC
-- =============================================
CREATE OR REPLACE FUNCTION join_weekly_league(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_week_start DATE := date_trunc('week', app_now())::DATE;
    v_prev_week_start TIMESTAMPTZ := date_trunc('week', app_now()) - INTERVAL '7 days';
    v_prev_week_end TIMESTAMPTZ := date_trunc('week', app_now());
    v_tier VARCHAR(20);
    v_school_id UUID;
    v_last_week_xp BIGINT;
    v_bucket INTEGER;
    v_group_id UUID;
BEGIN
    -- Idempotency: already in a group this week?
    IF EXISTS (
        SELECT 1 FROM league_group_members
        WHERE user_id = p_user_id AND week_start = v_week_start
    ) THEN
        RETURN;
    END IF;

    -- Get user's tier and school
    SELECT league_tier, school_id INTO v_tier, v_school_id
    FROM profiles WHERE id = p_user_id;

    IF v_tier IS NULL THEN RETURN; END IF;

    -- Calculate XP bucket from last week
    SELECT COALESCE(SUM(amount), 0) INTO v_last_week_xp
    FROM xp_logs
    WHERE user_id = p_user_id
    AND created_at >= v_prev_week_start
    AND created_at < v_prev_week_end;

    v_bucket := CASE
        WHEN v_last_week_xp = 0 THEN 0
        WHEN v_last_week_xp < 100 THEN 1
        WHEN v_last_week_xp < 300 THEN 2
        WHEN v_last_week_xp < 600 THEN 3
        ELSE 4
    END;

    -- Priority a: same tier + same bucket + same school member
    SELECT lg.id INTO v_group_id
    FROM league_groups lg
    WHERE lg.week_start = v_week_start AND lg.tier = v_tier AND lg.xp_bucket = v_bucket
    AND lg.member_count < 30
    AND EXISTS (
        SELECT 1 FROM league_group_members lgm
        WHERE lgm.group_id = lg.id AND lgm.school_id = v_school_id
    )
    ORDER BY lg.member_count DESC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    -- Priority b: same tier + same bucket
    IF v_group_id IS NULL THEN
        SELECT lg.id INTO v_group_id
        FROM league_groups lg
        WHERE lg.week_start = v_week_start AND lg.tier = v_tier AND lg.xp_bucket = v_bucket
        AND lg.member_count < 30
        ORDER BY lg.member_count DESC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    -- Priority c: neighbor bucket + same school
    IF v_group_id IS NULL THEN
        SELECT lg.id INTO v_group_id
        FROM league_groups lg
        WHERE lg.week_start = v_week_start AND lg.tier = v_tier
        AND lg.xp_bucket BETWEEN GREATEST(0, v_bucket - 1) AND LEAST(4, v_bucket + 1)
        AND lg.member_count < 30
        AND EXISTS (
            SELECT 1 FROM league_group_members lgm
            WHERE lgm.group_id = lg.id AND lgm.school_id = v_school_id
        )
        ORDER BY abs(lg.xp_bucket - v_bucket), lg.member_count DESC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    -- Priority d: neighbor bucket
    IF v_group_id IS NULL THEN
        SELECT lg.id INTO v_group_id
        FROM league_groups lg
        WHERE lg.week_start = v_week_start AND lg.tier = v_tier
        AND lg.xp_bucket BETWEEN GREATEST(0, v_bucket - 1) AND LEAST(4, v_bucket + 1)
        AND lg.member_count < 30
        ORDER BY abs(lg.xp_bucket - v_bucket), lg.member_count DESC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    -- Priority e: any bucket in same tier
    IF v_group_id IS NULL THEN
        SELECT lg.id INTO v_group_id
        FROM league_groups lg
        WHERE lg.week_start = v_week_start AND lg.tier = v_tier
        AND lg.member_count < 30
        ORDER BY lg.member_count DESC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    -- Priority f: create new group
    IF v_group_id IS NULL THEN
        INSERT INTO league_groups (week_start, tier, xp_bucket, member_count)
        VALUES (v_week_start, v_tier, v_bucket, 0)
        RETURNING id INTO v_group_id;
    END IF;

    -- Join the group
    INSERT INTO league_group_members (group_id, user_id, week_start, school_id)
    VALUES (v_group_id, p_user_id, v_week_start, v_school_id);

    UPDATE league_groups SET member_count = member_count + 1
    WHERE id = v_group_id;
END;
$$;
