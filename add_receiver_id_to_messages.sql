-- Add receiver_id to messages for easier unread count queries
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS receiver_id UUID REFERENCES auth.users(id);

-- Optional: Index for performance
CREATE INDEX IF NOT EXISTS messages_receiver_id_idx ON messages(receiver_id);
