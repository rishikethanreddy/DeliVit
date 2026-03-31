-- Add visibility flags to pickup_requests table to support "deleting" (hiding) chats
-- These columns default to TRUE so existing chats remain visible.

ALTER TABLE pickup_requests 
ADD COLUMN IF NOT EXISTS visible_to_requester BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS visible_to_carrier BOOLEAN DEFAULT TRUE;

-- Policy Update: Ensure users can update these flags for their own role
-- We already have a broad update policy in supabase_reset_policies.sql:
-- CREATE POLICY "Enable update for users" ...
-- It allows update if (auth.uid() = requester_id AND status = 'WAITING') OR (auth.uid() = carrier_id) ...
-- However, we need to allow updating visibility EVEN IF status is COMPLETED.

-- Let's create a specific policy for updating visibility to be safe and explicit.
-- Or better, ensure the main update policy covers this case.
-- The current policy "Enable update for users" might be too restrictive on status for Requesters.
-- "Enable update for users" allows (auth.uid() = requester_id AND status = 'WAITING')
-- This means a Requester CANNOT delete a COMPLETED chat because status != WAITING.
-- We need to fix this.

CREATE POLICY "Allow users to update chat visibility"
ON pickup_requests
FOR UPDATE
USING (
  (auth.uid() = requester_id) OR (auth.uid() = carrier_id)
)
WITH CHECK (
  (auth.uid() = requester_id) OR (auth.uid() = carrier_id)
);
-- Note: The above policy overlaps with others but ensures we can update visibility regardless of status.
-- Since Supabase policies are permissive (OR logic), adding this should enable the functionality.
