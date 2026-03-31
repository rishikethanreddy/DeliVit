import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FIREBASE_SERVER_KEY = Deno.env.get("FIREBASE_SERVER_KEY");

serve(async (req) => {
    try {
        const payload = await req.json();

        // Verify it's an insert on the messages table
        if (payload.type === "INSERT" && payload.table === "messages") {
            const message = payload.record;
            const receiverId = message.receiver_id;
            const senderId = message.sender_id;

            // Initialize Supabase Client to fetch tokens
            const supabaseAdmin = createClient(
                Deno.env.get("SUPABASE_URL") ?? "",
                Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
            );

            // Fetch the receiver's FCM Token & sender's name
            const { data: receiver } = await supabaseAdmin
                .from("profiles")
                .select("fcm_token")
                .eq("id", receiverId)
                .single();

            const { data: sender } = await supabaseAdmin
                .from("profiles")
                .select("full_name")
                .eq("id", senderId)
                .single();

            const fcmToken = receiver?.fcm_token;
            const senderName = sender?.full_name ?? "Someone";

            if (fcmToken) {
                // Send to Firebase Cloud Messaging (Legacy HTTP format for simplicity, or v1)
                const fcmRes = await fetch("https://fcm.googleapis.com/fcm/send", {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        Authorization: `key=${FIREBASE_SERVER_KEY}`,
                    },
                    body: JSON.stringify({
                        notification: {
                            title: `New message from ${senderName}`,
                            body: message.content,
                            badge: "1",
                            sound: "default",
                        },
                        data: {
                            requestId: message.request_id,
                        },
                        to: fcmToken,
                    }),
                });

                const fcmResponse = await fcmRes.json();
                console.log("FCM Response:", fcmResponse);

                return new Response(JSON.stringify({ success: true, fcmResponse }), {
                    headers: { "Content-Type": "application/json" },
                    status: 200,
                });
            }

            return new Response(JSON.stringify({ success: false, error: "No Token" }), {
                headers: { "Content-Type": "application/json" },
                status: 200,
            });
        }

        return new Response(JSON.stringify({ message: "Not an insert event" }), {
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { "Content-Type": "application/json" },
            status: 400,
        });
    }
});
