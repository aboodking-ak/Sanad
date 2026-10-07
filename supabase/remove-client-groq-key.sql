-- Run after deploying sanad-ai and verifying a signed-in request succeeds.
-- Older app versions that read this row will lose AI access.
DELETE FROM public.app_settings WHERE key = 'groq_api_key';
