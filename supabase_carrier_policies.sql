-- Policy: Allow ANY user to accept a request (Update status to ACCEPTED and carrier_id to themselves)
-- This applies when the request is currently WAITING and has NO carrier.
CREATE POLICY "Users can accept waiting requests"
ON pickup_requests
FOR UPDATE
USING (
  status = 'WAITING' AND carrier_id IS NULL
)
WITH CHECK (
  status = 'ACCEPTED' AND carrier_id = auth.uid()
);

-- Policy: Allow the assigned Carrier to update the status (e.g. to IN_TRANSIT, COMPLETED)
CREATE POLICY "Carriers can update request status"
ON pickup_requests
FOR UPDATE
USING (
  carrier_id = auth.uid()
)
WITH CHECK (
  carrier_id = auth.uid()
);
