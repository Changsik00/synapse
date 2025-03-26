# Matrix-Slack 통합 메신저 프로젝트

Slack `#bot_channel`과 Matrix 방을 Events API로 연동합니다.

## 구조

```plaintext
matrix-messenger/
├── config/                   # 설정 파일
├── data/                     # 데이터 저장소
├── scripts/                  # 설치 스크립트
├── .env                      # 환경 변수
├── docker-compose.yml        # Docker Compose 설정
└── README.md                 # 이 파일
```

## 사전 준비

1. Slack 앱 설정:
   - [Slack API](https://api.slack.com/apps) 에서 앱 선택.
   - "Event Subscriptions" 활성화 → Request URL: `https://synapse.scramble.team/slack`.
   - 이벤트 추가: `message.channels`.
   - 앱 설치 확인.
2. Slack 채널:
   - `#bot_channel`에서 `/invite @slack-bot`.

## 설치

1. `.env` 확인:

```plaintext
SLACK_BOT_TOKEN=#your_slack_bot_token
SLACK_EVENT_URL=https://synapse.scramble.team/slack
SLACK_CHANNEL_NAME=#bot_channel
MATRIX_ROOM_NAME=bot-channel-room
```

2. 실행:

```bash
cd scripts
chmod +x setup.sh
./setup.sh
```

## 확인

- `https://synapse.scramble.team` 접속 → Element로 로그인.
- `#bot_channel`에서 "Hello" 입력 → `bot-channel-room` 확인.
- `bot-channel-room`에서 "Hi" 입력 → `#bot_channel` 확인.
- `docker logs slack-bridge`: 이벤트 수신 확인.
- `docker logs synapse`: Synapse 상태 확인.
