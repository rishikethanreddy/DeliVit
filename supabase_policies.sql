-- Enable Row Level Security
ALTER TABLE pickup_requests ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to delete their own requests ONLY if they are 'WAITING'
CREATE POLICY "Users can delete their own waiting requests"
ON pickup_requests
FOR DELETE
USING (
  auth.uid() = requester_id 
  AND 
  status = 'WAITING'
);

-- Policy to allow users to update their own requests ONLY if they are 'WAITING'
-- This prevents users from changing details after a carrier has accepted.
CREATE POLICY "Users can update their own waiting requests"
ON pickup_requests
FOR UPDATE
USING (
  auth.uid() = requester_id 
  AND 
  status = 'WAITING'
)
WITH CHECK (
  auth.uid() = requester_id 
  AND 
  status = 'WAITING'
);

-- Note: Ensure existing SELECT and INSERT policies are also correct.
-- Typical SELECT policy:
-- CREATE POLICY "Everyone can view requests" ON pickup_requests FOR SELECT USING (true);
-- Typical INSERT policy:
-- CREATE POLICY "Users can insert their own requests" ON pickup_requests FOR INSERT WITH CHECK (auth.uid() = requester_id);
