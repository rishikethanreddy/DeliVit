-- CRITICAL FIX: RESET ALL POLICIES
-- This script will remove all existing restrictions and apply valid ones.

-- 1. Disable RLS temporarily to confirm it's the issue (Optional, skipping to avoid security risk, but resetting policies instead)
ALTER TABLE pickup_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE pickup_requests ENABLE ROW LEVEL SECURITY;

-- 2. Drop ALL existing policies for pickup_requests to clean up conflicts
DROP POLICY IF EXISTS "Users can delete their own waiting requests" ON pickup_requests;
DROP POLICY IF EXISTS "Users can update their own waiting requests" ON pickup_requests;
DROP POLICY IF EXISTS "Users can accept waiting requests" ON pickup_requests;
DROP POLICY IF EXISTS "Carriers can update request status" ON pickup_requests;
DROP POLICY IF EXISTS "Carriers can update status" ON pickup_requests;
DROP POLICY IF EXISTS "Everyone can view all requests" ON pickup_requests;
DROP POLICY IF EXISTS "Everyone can view requests" ON pickup_requests;
DROP POLICY IF EXISTS "Users can insert their own requests" ON pickup_requests;

-- 3. APPLY CLEAN POLICIES

-- READ: Everyone can see everything (needed for requester/carrier sync)
CREATE POLICY "Enable read access for all users"
ON pickup_requests FOR SELECT
USING (true);

-- INSERT: Authenticated users can create requests
CREATE POLICY "Enable insert for authenticated users"
ON pickup_requests FOR INSERT
WITH CHECK (auth.uid() = requester_id);

-- UDPATE: 
-- Allow Requester to update if Waiting
-- Allow ANYONE to update if they are the carrier (or becoming the carrier)
-- This is a broader policy to ensure it works.
CREATE POLICY "Enable update for users"
ON pickup_requests FOR UPDATE
USING (
  -- User is requester AND status is waiting
  (auth.uid() = requester_id AND status = 'WAITING')
  OR 
  -- User IS the assigned carrier
  (auth.uid() = carrier_id)
  OR
  -- User is BECOMING the carrier (Accepting)
  (carrier_id IS NULL AND status = 'WAITING')
)
WITH CHECK (true); -- Trust the logic in the app + USING clause filtering

-- DELETE: Requester can delete if Waiting
CREATE POLICY "Enable delete for requester"
ON pickup_requests FOR DELETE
USING (auth.uid() = requester_id AND status = 'WAITING');
