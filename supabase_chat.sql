-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid REFERENCES pickup_requests(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES auth.users(id) NOT NULL,
  content text NOT NULL CHECK (char_length(content) > 0),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see messages for requests they are involved in
CREATE POLICY "Users can view their request messages"
ON messages
FOR SELECT
USING (
  exists (
    select 1 from pickup_requests
    where id = messages.request_id
    and (requester_id = auth.uid() or carrier_id = auth.uid())
  )
);

-- Policy: Users can insert messages for requests they are involved in
CREATE POLICY "Users can send messages to their requests"
ON messages
FOR INSERT
WITH CHECK (
  auth.uid() = sender_id AND
  exists (
    select 1 from pickup_requests
    where id = request_id
    and (requester_id = auth.uid() or carrier_id = auth.uid())
  )
);

-- Realtime subscription
-- You must enable Realtime for this table in the Supabase Dashboard:
-- Database -> Replication -> Source -> bucket: supabase_realtime -> toggle 'messages' ON
