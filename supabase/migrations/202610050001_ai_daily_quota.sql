BEGIN;

CREATE TABLE IF NOT EXISTS public.sanad_ai_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  usage_date date NOT NULL,
  state text NOT NULL CHECK (state IN ('pending', 'succeeded', 'failed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '120 seconds'
);
CREATE INDEX IF NOT EXISTS sanad_ai_requests_user_day
  ON public.sanad_ai_requests(user_id, usage_date);
ALTER TABLE public.sanad_ai_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sanad_ai_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sanad_ai_requests TO service_role;

-- Only the authenticated Edge Function may call this RPC using its server key.
-- Successful replies count; pending reservations prevent concurrent overspending.
CREATE OR REPLACE FUNCTION public.sanad_ai_quota(
  p_user_id uuid,
  p_action text DEFAULT 'usage',
  p_request_id uuid DEFAULT NULL,
  p_success boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_day date := (now() AT TIME ZONE 'Asia/Baghdad')::date;
  v_used integer;
  v_pending integer;
  v_id uuid;
  v_accepted boolean := true;
  v_state text;
BEGIN
  IF p_user_id IS NULL OR p_action NOT IN ('usage', 'reserve', 'finish') THEN
    RAISE EXCEPTION 'Invalid quota request';
  END IF;
  IF p_action = 'finish' THEN
    SELECT usage_date INTO v_day FROM public.sanad_ai_requests
      WHERE id = p_request_id AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Unknown request'; END IF;
  END IF;

  -- Serialize all devices and reservations for the same account and day.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text || ':' || v_day::text, 0));
  UPDATE public.sanad_ai_requests SET state = 'failed'
    WHERE user_id = p_user_id AND usage_date = v_day
      AND state = 'pending' AND expires_at <= now();

  IF p_action = 'finish' THEN
    UPDATE public.sanad_ai_requests
      SET state = CASE WHEN p_success THEN 'succeeded' ELSE 'failed' END
      WHERE id = p_request_id AND user_id = p_user_id AND state = 'pending';
    SELECT state INTO v_state FROM public.sanad_ai_requests
      WHERE id = p_request_id AND user_id = p_user_id;
    v_accepted := (NOT p_success) OR v_state = 'succeeded';
  END IF;

  SELECT count(*) FILTER (WHERE state = 'succeeded'),
         count(*) FILTER (WHERE state = 'pending')
    INTO v_used, v_pending FROM public.sanad_ai_requests
    WHERE user_id = p_user_id AND usage_date = v_day;

  IF p_action = 'reserve' THEN
    IF v_used + v_pending >= 50 THEN
      v_accepted := false;
    ELSE
      INSERT INTO public.sanad_ai_requests(user_id, usage_date, state)
        VALUES (p_user_id, v_day, 'pending') RETURNING id INTO v_id;
      v_pending := v_pending + 1;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'accepted', v_accepted, 'request_id', v_id,
    'used', v_used, 'pending', v_pending, 'limit', 50,
    'remaining', greatest(0, 50 - v_used - v_pending),
    'reset_at', ((v_day + 1)::timestamp AT TIME ZONE 'Asia/Baghdad')
  );
END;
$$;
REVOKE ALL ON FUNCTION public.sanad_ai_quota(uuid, text, uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sanad_ai_quota(uuid, text, uuid, boolean) TO service_role;

COMMIT;
