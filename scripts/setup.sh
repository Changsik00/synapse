#!/bin/bash

cd "$(dirname "$0")/.."

# 1. 패키지 설치
sudo apt update
sudo apt install -y docker.io docker-compose curl jq certbot python3-certbot-nginx
sudo systemctl start docker
sudo systemctl enable docker

# 2. 디렉토리 생성
mkdir -p data/synapse-data data/slack-bridge-data config

# 3. Synapse 초기 설정
docker run -it --rm \
  -v $(pwd)/data/synapse-data:/data \
  -e SYNAPSE_SERVER_NAME=${SYNAPSE_SERVER_NAME} \
  -e SYNAPSE_REPORT_STATS=yes \
  matrixdotorg/synapse:latest generate

echo "app_service_config_files:
  - /config/slack-registration.yaml" >> data/synapse-data/homeserver.yaml

# 4. Slack 브릿지 등록 파일 생성
cat <<EOF > config/slack-registration.yaml
id: slack-bridge
url: http://slack-bridge:29328
as_token: $(openssl rand -hex 32)
hs_token: $(openssl rand -hex 32)
sender_localpart: slack-bot
namespaces:
  users:
    - exclusive: true
      regex: "@slack_.*:${SYNAPSE_SERVER_NAME}"
  rooms: []
  aliases: []
rate_limited: false
EOF

# 5. Docker Compose 시작
docker-compose up -d

# 6. HTTPS 인증서 발급
sudo certbot --nginx -d synapse.scramble.team --non-interactive --agree-tos -m your-email@example.com

# 7. 관리자 계정 생성
sleep 5
MATRIX_ACCESS_TOKEN=$(curl -s -X POST "http://localhost:8008/_matrix/client/r0/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"${SYNAPSE_ADMIN_USERNAME}\", \"password\": \"${SYNAPSE_ADMIN_PASSWORD}\", \"admin\": true}" | jq -r '.access_token')

# 8. Matrix 방 생성
MATRIX_ROOM_ID=$(curl -s -X POST "http://localhost:8008/_matrix/client/r0/createRoom" \
  -H "Authorization: Bearer ${MATRIX_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"${MATRIX_ROOM_NAME}\", \"preset\": \"private_chat\"}" | jq -r '.room_id')

# 9. Slack 채널과 Matrix 방 연동
curl -s -X POST "http://localhost:8008/_matrix/client/r0/rooms/${MATRIX_ROOM_ID}/send/m.room.message" \
  -H "Authorization: Bearer ${MATRIX_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"msgtype\": \"m.text\", \"body\": \"!slack link ${SLACK_CHANNEL_NAME}\"}"

echo "설치 완료! https://synapse.scramble.team 에서 확인하세요."
echo "관리자: ${SYNAPSE_ADMIN_USERNAME}/${SYNAPSE_ADMIN_PASSWORD}"
echo "Slack 채널: ${SLACK_CHANNEL_NAME}"
echo "Matrix 방: ${MATRIX_ROOM_NAME}"