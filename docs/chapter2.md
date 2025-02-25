### ec2에서 server 운영하기

### 전체 가이드

1. AWS ec2에서 서버 실행 (Route53 연동 되어 있음)
2. Nginx로 SSL 및 기본 was 서버
3. 내부 proxy를 사용해서 synapse 운영
4. postgreSQL을 superbase를 통해서 사용하고 synapse와 연동
5. 차후 브릿지는 별도로 학장하기

# Matrix Synapse Setup on AWS EC2

AWS EC2 인스턴스(Ubuntu)에서 Matrix Synapse 서버를 Docker로 운영하고, Nginx를 이용한 SSL 리버스 프록시 구성 및 외부 PostgreSQL(Supabase) 데이터베이스를 연결하는 설치 순서를 설명합니다.

> **전제조건:**  
>
> - AWS EC2 인스턴스가 생성되어 있고, Ubuntu가 설치되어 있음  
> - Route53에서 `synapse.scramble.team` 도메인이 EC2 인스턴스로 연결되어 있음  
> - 인바운드 포트: 80(HTTP), 443(HTTPS), 22(SSH)만 열려 있음  
> - Supabase에서 PostgreSQL 연결 문자열이 준비되어 있음

---

## Step 1: 시스템 업데이트 및 기본 도구 설치

1. SSH로 EC2 인스턴스에 접속합니다.
2. 시스템을 업데이트하고 필요한 패키지(도커, Nginx 등)를 설치합니다.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install docker.io docker-compose nginx -y
sudo systemctl enable --now docker
```

3. Docker Compose 설정
Docker Compose의 최신 버전을 설치합니다.
설치가 완료되면 버전을 확인합니다.

```bash
docker-compose --version
```

### Step 2: Synapse Docker 컨테이너 구성

- 작업 디렉터리를 만듭니다.

```bash
mkdir ~/synapse && cd ~/synapse
```

- docker-compose.yml 파일을 생성하고 아래 내용을 참고하여 작성합니다.

```yaml
version: '3'
services:
  synapse:
    image: matrixdotorg/synapse:latest
    container_name: synapse
    restart: unless-stopped
    volumes:
      - ./data:/data
    environment:
      - SYNAPSE_SERVER_NAME=synapse.scramble.team
      - SYNAPSE_REPORT_STATS=yes
    ports:
      - "8008:8008"    # 클라이언트-서버 API (내부 테스트용)
      - "8448:8448"    # Federation 포트 (내부 테스트용)
```

`./data` 디렉터리는 Synapse 데이터 및 설정 파일(homeserver.yaml)이 저장되는 위치입니다.

### Step 3: Synapse 설정 파일 수정 (homeserver.yaml)

- 아래 명령어를 실행하면, Synapse 설정 파일이 `~/synapse/data/homeserver.yaml` 경로에 생성됩니다.
- 명령어는 [링크 참고](https://hub.docker.com/r/matrixdotorg/synapse)

```bash
 sudo docker run -it --rm \
  -v ~/synapse/data:/data \
  -e SYNAPSE_SERVER_NAME=synapse.scramble.team \
  -e SYNAPSE_REPORT_STATS=yes \
  matrixdotorg/synapse:latest generate
```

- `vi ~/synapse/data/homeserver.yaml`

```yaml
server_name: "synapse.scramble.team"
# ...
database:
  name: psycopg2
  args:
    host: db.wymlzcinpeivjbneygok.supabase.co
    port: 5432
    database: postgres
    user: postgres
    password: "uvKSA_.k-*tp4.4"
    cp_min: 5
    cp_max: 10
# Federation 관련 및 기타 옵션은 기본 설정 유지하거나 필요에 맞게 수정    
```

참고:
특수문자가 포함된 비밀번호는 큰따옴표(" ")로 감싸주세요.
Supabase DB는 외부에서 접근할 수 있도록 EC2 인스턴스의 공인 IP가 허용되어야 합니다.

### Step 4:  Nginx 리버스 프록시 및 SSL 구성

- Certbot을 사용한 SSL 인증서 발급
Let's Encrypt의 Certbot을 사용하여 synapse.scramble.team 도메인에 대해 SSL 인증서를 발급합니다.
Certbot 설치:

```bash
sudo apt install certbot python3-certbot-nginx -y
```

Certbot을 통해 인증서 발급 및 자동 Nginx 설정 적용:
진행 중 이메일 입력 및 서비스 약관 동의 후, Certbot이 자동으로 Nginx 설정에 SSL 관련 블록을 추가합니다.

```bash
sudo certbot --nginx -d synapse.scramble.team
```

인증서 갱신 테스트:

```bash
sudo certbot renew --dry-run
```

- Nginx 설정 파일을 생성 또는 수정합니다. 예를 들어 /etc/nginx/sites-available/synapse 파일을 만듭니다.

```bash
server {
    listen 80;
    server_name synapse.scramble.team;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name synapse.scramble.team;

    ssl_certificate /etc/letsencrypt/live/synapse.scramble.team/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/synapse.scramble.team/privkey.pem;

    # 모든 Matrix 요청을 8008 포트로 전달
    location / {
        proxy_pass http://127.0.0.1:8008;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
    }

    # .well-known/matrix/server 엔드포인트 제공
    location = /.well-known/matrix/server {
        add_header Content-Type "application/json";
        # :443을 명시해두면 외부 서버들이 "443 포트로 접속하라"고 인식
        return 200 '{"m.server": "synapse.scramble.team:443"}';
    }
}

```

- Nginx 설정을 활성화하고 테스트합니다.

```bash
sudo ln -s /etc/nginx/sites-available/synapse /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Step 5: Synapse 컨테이너 실행

- 모든 설정이 완료되면 Synapse 컨테이너를 백그라운드로 실행합니다.
- 필요시 `sudo docker-compose down` 사용을 하고 시작 해야 합니다.

```bash
cd ~/synapse
sudo docker-compose up -d
sudo docker-compose logs -f synapse 
```

### Step 6: 사용자 추가

```bash
docker exec -it synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u admin -p password --admin
```

### 사용자 공개 가입 허용

- `enable_registration: true` -> 동작안함

- homeserver.yaml 예시

```yaml
# ========================================================================
# Example homeserver.yaml for Synapse with open registration enabled
# ========================================================================

# 서버의 고유 이름(도메인) - Matrix ID에서 : 뒤에 들어가는 부분
server_name: "synapse.scramble.team"

# Synapse PID 파일 위치
pid_file: /data/homeserver.pid

# Synapse가 수신할 포트 및 리스너 설정
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      # 클라이언트 및 페더레이션 트래픽을 모두 처리
      - names: [client, federation]
        compress: false

# 데이터베이스 설정 (SQLite 예시)
database:
  name: sqlite3
  args:
    database: /data/homeserver.db

# 로그 설정 파일 경로
log_config: "/data/synapse.scramble.team.log.config"

# 미디어 저장소 경로
media_store_path: /data/media_store

# 회원가입에 사용되는 공유 시크릿 (Admin API 등을 통한 사용자 등록 시 필요)
registration_shared_secret: "BfHZS7wK3cx@Frd^2STqgdBkjZCC_SBUDCF2*=wUy~xR*pTq:b"

# 서버 통계 보고 활성화 (true일 경우 Synapse 개발팀에 익명 통계 보고)
report_stats: true

# 매트릭스 엑세스 토큰 등을 서명할 때 사용하는 키 (임의의 긴 문자열)
macaroon_secret_key: "P2:SP963hR6KO&iSGVoKU.0guyaQm~gcL19&SovkUAL1250Z9E"

# 웹 양식(form) 전송 시 사용하는 시크릿 키
form_secret: "5y4n=znNXttQNN2UnQ+VikVgRy4HBDN:xvDbBRTxGCldvTj+N0"

# 서버 서명 키 파일 경로 (처음에 Synapse가 자동 생성)
signing_key_path: "/data/synapse.scramble.team.signing.key"

# Matrix.org 키 서버를 신뢰 (기본값)
trusted_key_servers:
  - server_name: "matrix.org"

# ========================================================================
# vim:ft=yaml
# ========================================================================
```
