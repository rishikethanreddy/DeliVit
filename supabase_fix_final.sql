-- RLS FIX: Run this in Supabase SQL Editor

-- 1. DROP potential conflicting or restrictive policies to be safe (Optional, but recommended if unsure)
DROP POLICY IF EXISTS "Carriers can update request status" ON pickup_requests;
DROP POLICY IF EXISTS "Users can accept waiting requests" ON pickup_requests;

-- 2. Allow Everyone to VIEW requests (Critical for StreamBuilder to work for both parties)
-- If you already have a SELECT policy, this might error, but it ensures carriers can see the request.
CREATE POLICY "Everyone can view all requests"
ON pickup_requests FOR SELECT
USING (true);

-- 3. Allow Users to ACCEPT requests (Start the valid carrier flow)
CREATE POLICY "Users can accept waiting requests"
ON pickup_requests
FOR UPDATE
USING (status = 'WAITING' AND carrier_id IS NULL)
WITH CHECK (status = 'ACCEPTED' AND carrier_id = auth.uid());

-- 4. Allow Carriers to UPDATE status (In Transit, Completed)
CREATE POLICY "Carriers can update status"
ON pickup_requests
FOR UPDATE
USING (carrier_id = auth.uid())
WITH CHECK (carrier_id = auth.uid());
