# Complete UAT Test Commands

Once the database authentication issue is resolved, run these commands in sequence:

## 1. Start the Server
```bash
cd backend
npm run dev
```

## 2. Health Check
```bash
curl http://localhost:5000/api/health
```

## 3. Create Test Users

### Create Organizer
```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "organizer@test.com",
    "password": "password123",
    "role": "organizer"
  }'
```

### Create Player
```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "player@test.com", 
    "password": "password123",
    "role": "player"
  }'
```

## 4. Login Users and Get Tokens

### Login Organizer
```bash
ORGANIZER_TOKEN=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "organizer@test.com", "password": "password123"}' \
  | jq -r '.token')

echo "Organizer Token: $ORGANIZER_TOKEN"
```

### Login Player
```bash
PLAYER_TOKEN=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "player@test.com", "password": "password123"}' \
  | jq -r '.token')

echo "Player Token: $PLAYER_TOKEN"
```

## 5. Event Management Tests

### Create Event (Organizer)
```bash
EVENT_RESPONSE=$(curl -s -X POST http://localhost:5000/api/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ORGANIZER_TOKEN" \
  -d '{
    "title": "CS:GO Championship 2024",
    "description": "Professional esports tournament",
    "game": "Counter-Strike: Global Offensive",
    "start_time": "2024-12-01T10:00:00Z",
    "end_time": "2024-12-01T20:00:00Z",
    "bracket_type": "single_elimination",
    "max_teams": 16
  }')

EVENT_ID=$(echo $EVENT_RESPONSE | jq -r '.event.id')
echo "Created Event ID: $EVENT_ID"
```

### List Events (Public)
```bash
curl http://localhost:5000/api/events
```

### Player Joins Event
```bash
curl -X POST http://localhost:5000/api/events/$EVENT_ID/join \
  -H "Authorization: Bearer $PLAYER_TOKEN"
```

## 6. Payment Webhook Test
```bash
curl -X POST http://localhost:5000/api/webhooks/payment \
  -H "Content-Type: application/json" \
  -d '{
    "external_payment_ref": "pending_123_player_id",
    "status": "completed",
    "webhook_secret": "test-webhook-secret-key"
  }'
```

## 7. Check Ticket Status
```bash
curl http://localhost:5000/api/tickets?userId=player_user_id \
  -H "Authorization: Bearer $PLAYER_TOKEN"
```

## 8. Security Tests

### Unauthorized Event Creation (Should Fail)
```bash
curl -X POST http://localhost:5000/api/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $PLAYER_TOKEN" \
  -d '{
    "title": "Unauthorized Event",
    "game": "Test Game",
    "start_time": "2024-12-01T10:00:00Z",
    "end_time": "2024-12-01T20:00:00Z"
  }'
```

### Invalid Webhook Secret (Should Fail)
```bash
curl -X POST http://localhost:5000/api/webhooks/payment \
  -H "Content-Type: application/json" \
  -d '{
    "external_payment_ref": "test_ref",
    "status": "completed",
    "webhook_secret": "wrong_secret"
  }'
```

## 9. Match/Bracket Generation
```bash
curl -X POST http://localhost:5000/api/events/$EVENT_ID/matches \
  -H "Authorization: Bearer $ORGANIZER_TOKEN"

curl http://localhost:5000/api/events/$EVENT_ID
```

## Expected Results
- Registration: 201 Created with JWT tokens
- Login: 200 OK with JWT tokens  
- Event Creation: 201 Created (organizer only)
- Event Listing: 200 OK with event array
- Event Join: 200 OK with ticket creation
- Webhook: 200 OK with ticket status update
- Security Tests: 403 Forbidden / 401 Unauthorized
- Match Generation: 201 Created with matches

## Troubleshooting Database Issues

If you encounter PostgreSQL authentication issues:

1. **Set PostgreSQL Password** (if needed):
```bash
ALTER USER postgres PASSWORD 'your_password';
```

2. **Update .env file**:
```
DATABASE_URL=postgresql://postgres:your_password@localhost:5432/postgres
```

3. **Alternative: Trust Authentication**
Edit `pg_hba.conf` and change `scram-sha-256` to `trust` for localhost connections, then restart PostgreSQL.