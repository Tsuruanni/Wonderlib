-- =============================================
-- Replace emoji icons on the 4 league tier badges with their corresponding
-- rank PNG asset paths. The widget detects 'assets/' prefix and renders via
-- Image.asset instead of Text(emoji).
-- =============================================

UPDATE badges SET icon = 'assets/icons/rank-silver-2_large.png'
    WHERE slug = 'league-tier-silver';

UPDATE badges SET icon = 'assets/icons/rank-gold-3_large.png'
    WHERE slug = 'league-tier-gold';

UPDATE badges SET icon = 'assets/icons/rank-platinum-5_large.png'
    WHERE slug = 'league-tier-platinum';

UPDATE badges SET icon = 'assets/icons/rank-diamond-7_large.png'
    WHERE slug = 'league-tier-diamond';
