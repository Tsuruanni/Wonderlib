-- Admin-editable API configuration: keys + model parameters for the
-- generative services we call from edge functions (Gemini + fal.ai).
--
-- Phase 1 of the migration: only adds the rows so the admin UI can edit
-- them. Edge functions still read from Deno.env in this phase. Phase 2
-- will update each function to fall back to system_settings when the
-- env var is empty.
--
-- All values stored as JSONB strings so the existing settings UI works
-- without schema changes. Sensitive keys (`*_api_key`) are detected by
-- the admin client and rendered with masked/show-hide inputs.

INSERT INTO system_settings (key, value, category, description, group_label, sort_order) VALUES
  -- Gemini (Google generative AI — vocabulary/activity content generation)
  ('gemini_api_key', '""', 'api', 'Google AI Studio''dan alınan API anahtarı. Boş bırakılırsa edge function env vars kullanılır.', 'Gemini', 1),
  ('gemini_model', '"gemini-2.0-flash"', 'api', 'Hangi Gemini modeli (örn: gemini-2.0-flash, gemini-2.5-pro).', 'Gemini', 2),
  ('gemini_temperature', '"0.3"', 'api', 'Yaratıcılık (0.0 = deterministik, 1.0 = yaratıcı).', 'Gemini', 3),

  -- fal.ai (TTS for audio + image generation)
  ('fal_api_key', '""', 'api', 'fal.ai dashboard''dan alınan API anahtarı.', 'fal.ai', 10),
  ('fal_tts_model', '"fal-ai/elevenlabs/tts/eleven-v3"', 'api', 'TTS model endpoint''i (örn: fal-ai/elevenlabs/tts/eleven-v3, fal-ai/kokoro).', 'fal.ai', 11),
  ('fal_tts_voice_id', '"Rachel"', 'api', 'TTS voice ID (ElevenLabs voice adı veya UUID).', 'fal.ai', 12),
  ('fal_image_model', '"fal-ai/nano-banana-pro"', 'api', 'Görsel üretim modeli (örn: fal-ai/nano-banana-pro, fal-ai/flux-pro).', 'fal.ai', 13)
ON CONFLICT (key) DO NOTHING;
