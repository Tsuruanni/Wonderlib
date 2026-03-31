-- Fix notif_badge_earned: was inserted without sort_order (defaulted to 0)
-- and with unquoted 'true' instead of '"true"' used by all other notification settings.
-- Slot badge_earned at 8, bump assignment from 8 → 9.
UPDATE system_settings SET sort_order = 8, value = '"true"' WHERE key = 'notif_badge_earned';
UPDATE system_settings SET sort_order = 9 WHERE key = 'notif_assignment';
