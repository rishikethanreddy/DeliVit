// Setup:
// 1. Create a Firebase Project and enable Cloud Messaging (V1).
// 2. Generate a Private Key JSON (Service Account) in Firebase Console > Project Settings > Service Accounts.
// 3. Save the JSON content as a Supabase Secret:
//    supabase secrets set FCM_SERVICE_ACCOUNT='{"type": "service_account", ...}'

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { JWT } from "https://esm.sh/google-auth-library@9.0.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

serve(async (req) => {
  // 1. Parse the Webhook Payload
  const payload = await req.json();
  const record = payload.record; // The new message row

  if (!record || !record.receiver_id || !record.content) {
    return new Response(JSON.stringify({ error: "Invalid payload" }), { headers: { "Content-Type": "application/json" } });
  }

  // 2. Get the Receiver's FCM Token
  const { data: user, error } = await supabase
    .from("profiles")
    .select("fcm_token")
    .eq("id", record.receiver_id)
    .single();

  if (error || !user?.fcm_token) {
    console.log("No FCM token found for user", record.receiver_id);
    return new Response(JSON.stringify({ message: "No token found" }), { headers: { "Content-Type": "application/json" } });
  }

  // 3. Get Access Token for FCM (using Service Account)
  const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
  
  const jwtClient = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const tokens = await jwtClient.authorize();
  const accessToken = tokens.access_token;

  // 4. Send Notification
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
  
  const response = await fetch(fcmUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token: user.fcm_token,
        notification: {
          title: "New Message",
          body: record.content,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          sender_id: record.sender_id,
          request_id: record.request_id,
        },
      },
    }),
  });

  const result = await response.json();
  console.log("FCM Response:", result);

  return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" } });
});
