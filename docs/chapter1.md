### 1. Docker 설치

먼저, Docker가 설치되어 있어야 합니다. 아직 설치하지 않았다면, 아래 링크에서 Docker를 설치할 수 있습니다.

- [Docker 설치 가이드](https://docs.docker.com/get-docker/)

### 2. Synapse Docker 이미지 다운로드

Docker가 설치되었다면, Synapse Docker 이미지를 다운로드합니다.

```bash
docker pull matrixdotorg/synapse
```

### 3. Synapse 설정 파일 생성

Synapse를 실행하기 전에 설정 파일을 생성해야 합니다. Docker 컨테이너를 임시로 실행하여 설정 파일을 생성할 수 있습니다.

```bash
docker run -it --rm \
    -v "$(pwd)/data:/data" \
    -e SYNAPSE_SERVER_NAME=my.matrix.host \
    -e SYNAPSE_REPORT_STATS=yes \
    matrixdotorg/synapse:latest generate
```

- `my.matrix.host` 부분을 자신의 도메인으로 변경해야 합니다. 로컬에서 테스트할 경우 `localhost`로 설정할 수 있습니다.
- `data` 디렉토리에 설정 파일이 생성됩니다.

### 4. Synapse 실행

이제 Synapse를 실행할 준비가 되었습니다. 다음 명령어로 Synapse를 실행합니다.

```bash
docker run -d \
    -v "$(pwd)/data:/data" \
    -p 8008:8008 \
    --name synapse \
    matrixdotorg/synapse:latest
```

- `d` 옵션은 컨테이너를 백그라운드에서 실행합니다.
- `v "$(pwd)/data:/data"`는 호스트의 `data` 디렉토리를 컨테이너의 `/data` 디렉토리에 마운트합니다.
- `p 8008:8008`는 호스트의 8008 포트를 컨테이너의 8008 포트에 매핑합니다.

### 5. 서버 접속

이제 브라우저에서 `http://localhost:8008`로 접속하여 Synapse 서버가 실행 중인지 확인할 수 있습니다.

### 6. 관리자 계정 생성

초기 설정에서는 관리자 계정이 없으므로, 관리자 계정을 생성해야 합니다. 다음 명령어로 관리자 계정을 생성할 수 있습니다.

```bash
docker exec -it synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml --help
```

- `-help` 옵션을 제거하고, `u` 옵션으로 사용자 이름, `p` 옵션으로 비밀번호를 설정할 수 있습니다.
- 예시:

```bash
docker exec -it synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml -u admin -p password --admin
```

### 7. 클라이언트 연결

이제 Matrix 클라이언트(예: Element)를 사용하여 생성한 서버에 연결할 수 있습니다. 클라이언트에서 서버 주소로 `http://localhost:8008`를 입력하고, 생성한 계정으로 로그인하면 됩니다.

### 8. 서버 중지 및 삭제

테스트가 끝나면 다음 명령어로 서버를 중지하고 삭제할 수 있습니다.

```bash
docker stop synapse
docker rm synapse
```

이제 로컬에서 Synapse를 사용하여 Matrix 서버를 테스트할 수 있습니다. 추가적인 설정이나 문제가 발생하면 [Synapse 공식 문서](https://matrix-org.github.io/synapse/latest/)를 참고하세요.
