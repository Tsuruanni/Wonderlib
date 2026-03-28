-- Add mock library mode toggle to system settings
INSERT INTO system_settings (key, value, category, description, sort_order)
VALUES (
  'mock_library_enabled',
  '"false"',
  'app',
  'Kütüphane Demo Modu — Kilitli demo kitapları kütüphanede göster',
  100
)
ON CONFLICT (key) DO NOTHING;
