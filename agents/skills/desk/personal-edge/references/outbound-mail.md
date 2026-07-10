# Send an alert

Use the existing `RESEND_API_KEY` and verified `bekkevard.me` Resend domain.
Cloudflare Email Sending requires Workers Paid and is outside this lane. Send
only to the user-authorized destination.

Validate the domain, then send:

```bash
curl --fail --silent --show-error \
  --header "Authorization: Bearer $RESEND_API_KEY" \
  https://api.resend.com/domains

payload=$(jq -nc '{
  from: "Personal Edge <alerts@bekkevard.me>",
  to: ["anders.bekkevard@gmail.com"],
  subject: "Personal edge alert",
  text: "The automation completed."
}')
curl --fail --silent --show-error --request POST \
  --header "Authorization: Bearer $RESEND_API_KEY" \
  --header 'Content-Type: application/json' \
  --data "$payload" \
  https://api.resend.com/emails
```

Use the returned id with `GET /emails/{id}` and require
`last_event: delivered`. Confirm mailbox delivery when authorized mail or
browser access is available.
