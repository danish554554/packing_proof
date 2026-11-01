-- ==============================================================================
-- PackProof SaaS - Database Schema for Supabase
-- Run this in your Supabase Project -> SQL Editor -> Run
-- ==============================================================================

-- 1. Create Sellers Table
CREATE TABLE IF NOT EXISTS public.sellers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    seller_name TEXT NOT NULL DEFAULT 'Valued Seller',
    store_name TEXT DEFAULT '',
    phone_number TEXT DEFAULT '',
    
    -- Subscription details
    plan TEXT NOT NULL DEFAULT 'silver' CHECK (plan IN ('silver', 'gold', 'platinum')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    
    -- Quota management
    monthly_quota INT NOT NULL DEFAULT 100, -- 100 for silver, 200 for gold, 999999 for platinum
    videos_recorded_this_month INT NOT NULL DEFAULT 0,
    quota_reset_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Create Order Proofs Audit Log
CREATE TABLE IF NOT EXISTS public.order_proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES public.sellers(id) ON DELETE CASCADE,
    tracking_number TEXT NOT NULL,
    order_type TEXT NOT NULL DEFAULT 'packing',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.sellers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_proofs ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for Sellers
DROP POLICY IF EXISTS "Sellers can view own profile" ON public.sellers;
CREATE POLICY "Sellers can view own profile" 
ON public.sellers FOR SELECT 
TO authenticated 
USING (auth.uid() = id);

-- 5. RLS Policies for Order Proofs
DROP POLICY IF EXISTS "Sellers can view own proofs" ON public.order_proofs;
CREATE POLICY "Sellers can view own proofs" 
ON public.order_proofs FOR SELECT 
TO authenticated 
USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Sellers can insert own proofs" ON public.order_proofs;
CREATE POLICY "Sellers can insert own proofs" 
ON public.order_proofs FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = seller_id);

-- 6. Trigger to automatically create a seller row when a user is created in Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.sellers (
        id, 
        email, 
        seller_name, 
        plan, 
        monthly_quota, 
        expires_at, 
        is_active
    ) VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'seller_name', split_part(NEW.email, '@', 1)),
        'silver',
        100,
        NOW() + INTERVAL '30 days',
        true
    ) ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 7. RPC Function: Securely record order proof and increment monthly counter
CREATE OR REPLACE FUNCTION public.record_order_proof(
    p_tracking_number TEXT,
    p_order_type TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_seller public.sellers%ROWTYPE;
    v_new_count INT;
BEGIN
    -- Fetch seller record
    SELECT * INTO v_seller FROM public.sellers WHERE id = auth.uid();
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Seller profile not found');
    END IF;
    
    -- Check if active
    IF NOT v_seller.is_active THEN
        RETURN jsonb_build_object('success', false, 'error', 'Account is deactivated');
    END IF;
    
    -- Check if expired
    IF NOW() > v_seller.expires_at THEN
        RETURN jsonb_build_object('success', false, 'error', 'Subscription expired');
    END IF;
    
    -- Check quota
    IF v_seller.plan <> 'platinum' AND v_seller.videos_recorded_this_month >= v_seller.monthly_quota THEN
        RETURN jsonb_build_object('success', false, 'error', 'Monthly quota exceeded');
    END IF;
    
    -- Insert audit record
    INSERT INTO public.order_proofs (seller_id, tracking_number, order_type)
    VALUES (auth.uid(), p_tracking_number, p_order_type);
    
    -- Increment count
    UPDATE public.sellers 
    SET videos_recorded_this_month = videos_recorded_this_month + 1,
        updated_at = NOW()
    WHERE id = auth.uid()
    RETURNING videos_recorded_this_month INTO v_new_count;
    
    RETURN jsonb_build_object(
        'success', true, 
        'videos_recorded_this_month', v_new_count,
        'remaining_quota', GREATEST(0, v_seller.monthly_quota - v_new_count)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
