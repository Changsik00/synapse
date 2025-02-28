## Matrix와 Slack 브릿지 설정 가이드

### 개요 및 정의

#### Matrix와 Slack 브릿지란?

    Matrix: 오픈소스 분산 통신 프로토콜로, 실시간 채팅과 데이터 동기화를 지원합니다. 시냅스(Synapse)는 Matrix를 구현한 홈서버 소프트웨어예요.
    Slack: 팀 협업을 위한 메신저 플랫폼입니다.
    matrix-appservice-slack: Matrix와 Slack을 연결하는 브릿지로, 두 플랫폼 간 메시지를 주고받을 수 있게 해줍니다. 예를 들어, Slack 채널에서 보낸 메시지가 Matrix 방에 나타나고, 반대도 가능해요.

### 목적

    사용자의 시냅스 서버(synapse.scramble.team)에 Slack 브릿지를 설정해서 두 플랫폼을 연동하려는 목표예요.

* 초기 질문 및 이해가 안 됐던 부분
* 초기 질문

    사용자가 제공한 링크: matrix-appservice-slack 문서
    요청: 시냅스 서버에 Slack을 연동하려고 브릿지를 설정하는 방법을 설명해 달라는 질문.

* 이해가 안 됐던 부분

    설치 방식 혼동:
        git clone으로 시작했는데, 문서에 Docker 명령어가 섞여 있어서 헷갈렸어요.
        해결: Node.js 방식으로 통일해서 진행.
    Slack 봇 토큰:
        "Slack 봇 토큰 (나중에 추가)가 뭐지?"라는 질문.
        해결: Slack에서 봇 토큰을 발급받아 config.yaml에 추가하는 과정 설명.
    connectionString 이상함:
        config.sample.yaml에 bot_token과 connectionString 관련 설정이 명확하지 않아 혼란.
        해결: bot_token은 직접 추가해야 하고, connectionString은 PostgreSQL 설정 시 필요함을 설명.

* 진행 과정에서 발생한 문제와 해결

1. 초기 설치 및 설정

    문제: git clone과 Docker 혼용으로 혼란.
    해결: Node.js 방식으로 진행:
    text

```bash
git clone <https://github.com/matrix-org/matrix-appservice-slack.git>
cd matrix-appservice-slack
npm install
npm run build
```

config.yaml 설정:

```yaml
    homeserver:
      url: "https://synapse.scramble.team"
      server_name: "scramble.team"
    slack:
      bot_token: "xoxb-..."
    bridge:
      port: 9898
```

2. slack-registration.yaml 생성 실패

    문제: 브릿지 실행 시 ENOENT: no such file or directory, open 'slack-registration.yaml' 에러.
    해결: 등록 파일 생성:
    text

    sudo node lib/app.js -r -c config/config.yaml -u "<http://localhost:9898>" -f slack-registration.yaml

3. 시냅스에서 slack-registration.yaml 인식 실패

    문제: homeserver.yaml에 추가했는데 FileNotFoundError 발생:
    text

FileNotFoundError: [Errno 2] No such file or directory: '/home/ubuntu/synapse/matrix-appservice-slack/slack-registration.yaml'
원인: 파일은 존재했지만, 시냅스(synapse 사용자)가 /home/ubuntu/에 접근 못 함.
해결: 파일을 /data/로 이동:

```bash
sudo mv /home/ubuntu/synapse/matrix-appservice-slack/slack-registration.yaml /data/slack-registration.yaml
```

    homeserver.yaml 수정:
    yaml

app_service_config_files:

* "/data/slack-registration.yaml"
시냅스 재시작:
text

        sudo systemctl restart matrix-synapse

1. PostgreSQL 연결 문제

    문제: 브릿지 실행 시 ECONNREFUSED 에러:
    text

"Failed to get schema version:", {"errno":-111,"code":"ECONNREFUSED","address":"127.0.0.1","port":5432}
원인: PostgreSQL이 설치 안 됐거나 설정 안 됨.
해결:

    PostgreSQL 설치:
    text

sudo apt install postgresql postgresql-contrib
사용자와 데이터베이스 생성:
text
sudo -u postgres psql
CREATE USER slackbridge WITH PASSWORD 'mypgpass123';
CREATE DATABASE slack_bridge OWNER slackbridge;
\q
config.yaml에 db 추가:
yaml
db:
  engine: "postgres"
  connectionString: "postgres://slackbridge:mypgpass123@localhost:5432/slack_bridge?sslmode=disable"
브릿지 실행 성공:
text
sudo node lib/app.js -c config/config.yaml -u "<http://localhost:9898>"

    출력:
    text

            INFO 10:04:58:387 [PgDatastore] Database schema is at version v16
            INFO 10:04:58:396 [SlackHookHandler] Slack-side listening on port 9898 over http

5. 로그 경고

    문제: "Attempt to write logs with no transports" 경고.
    해결: config.yaml에 로깅 추가:
    yaml

    logging:
      level: "info"
      console: true

최종 설정
homeserver.yaml
yaml
server_name: "synapse.scramble.team"
pid_file: /data/homeserver.pid
listeners:

* port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
  * names: [client, federation]
        compress: false
database:
  name: sqlite3
  args:
    database: /data/homeserver.db
app_service_config_files:
* "/data/slack-registration.yaml"
slack-registration.yaml
yaml
id: 83b1225a4485b633d78629a9ce6996dab2c91c94923601deb0fc299e31698627
hs_token: d83a7b9141646f8f8c56eb4a7a777433ad0870facf64c40acf3c0dafb638fecd
as_token: cb86921e15090e0c0ed4ee5e75e57cfbce7ac2a9455a0c2d8a1faa3a4e0c4944
url: <http://localhost:9898>
sender_localpart: slackbot
namespaces:
  users:
  * exclusive: true
      regex: '@slack_.*:scramble.team'
config.yaml
yaml
homeserver:
  url: "<https://synapse.scramble.team>"
  server_name: "scramble.team"
slack:
  bot_token: "xoxb-..."
bridge:
  port: 9898
db:
  engine: "postgres"
  connectionString: "postgres://slackbridge:mypgpass123@localhost:5432/slack_bridge?sslmode=disable"
logging:
  level: "info"
  console: true
실행 및 테스트

    브릿지 실행:
    text

cd /home/ubuntu/synapse/matrix-appservice-slack
sudo node lib/app.js -c config/config.yaml -u "<http://localhost:9898>"
Matrix에서 테스트:

    @slackbot:scramble.team 초대:
    text

/invite @slackbot:scramble.team
Slack 채널 연결:
text

    link #slack-channel-name

지속 실행 (선택):
text

    sudo npm install -g pm2
    pm2 start "node lib/app.js -c config/config.yaml -u http://localhost:9898" --name slack-bridge
    pm2 save
    pm2 startup

결론

    초기 혼동과 여러 에러를 거쳐, Slack 브릿지가 synapse.scramble.team에 성공적으로 연동됐어요.
    파일 경로 문제와 PostgreSQL 설정이 주요 걸림돌이었지만, 모두 해결해서 이제 Matrix와 Slack이 연결된 상태예요.
    추가 질문이나 문제가 있으면 언제든 물어보세요!
