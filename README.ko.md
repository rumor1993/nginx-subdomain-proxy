#  Nginx Reverse Proxy with Let's Encrypt Auto-Renewal

[English](README.md)

AWS Route53 DNS 인증을 사용하여 Let's Encrypt 와일드카드 SSL 인증서를 발급받고, 서브도메인별로 다른 애플리케이션을 프록시하는 Nginx 리버스 프록시 서버입니다.

## 사전 요구사항

- Docker 및 Docker Compose 설치
- AWS Route53에 등록된 도메인
- AWS IAM 사용자 및 액세스 키 (Route53 권한 필요)

## 설정

### 1. 환경 변수 설정

`.env.example` 파일을 `.env`로 복사하고 실제 값으로 수정합니다.

```bash
cp .env.example .env
```

`.env` 파일에 다음 정보를 입력합니다:

```
AWS_ACCESS_KEY_ID=your_aws_access_key_id
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
AWS_REGION=ap-northeast-2
MY_DOMAIN=your-domain.com
MY_EMAIL=your-email@example.com
```

## 사용법

### 최초 실행 시 (중요)

최초 실행 시에는 **반드시 certbot을 먼저 실행**하여 SSL 인증서를 발급받아야 합니다.

#### 1단계: Certbot으로 SSL 인증서 발급

```bash
docker-compose run --rm certbot
```

인증서 발급이 완료되면 `certbot/conf` 디렉토리에 Let's Encrypt 인증서가 저장됩니다.

#### 2단계: Nginx 실행

```bash
docker-compose up -d nginx
```

Nginx가 시작되면서 `.env` 파일의 `MY_DOMAIN` 값을 사용하여 자동으로 설정 파일을 생성합니다.

### 애플리케이션 실행

호스트에서 각 애플리케이션을 포트 바인딩하여 실행합니다:

```bash
# app1 - 포트 3001로 바인딩
docker run -d -p 3001:3000 your-app1-image

# app2 - 포트 3002로 바인딩
docker run -d -p 3002:3000 your-app2-image
```

nginx가 `host.docker.internal`을 통해 호스트의 포트로 프록시합니다.

### 새 서브도메인 추가

1. 새로운 설정 파일 생성:

```bash
# nginx/conf.d/app3.conf.template
cp nginx/conf.d/app1.conf.template nginx/conf.d/app3.conf.template
```

2. 파일 내용 수정:

```nginx
server {
    listen 443 ssl http2;
    server_name app3.${MY_DOMAIN};

    # ... SSL 설정 ...

    location / {
        proxy_pass http://host.docker.internal:3003;  # 포트 변경
        # ... 프록시 헤더 설정 ...
    }
}
```

3. nginx 재시작:

```bash
docker-compose restart nginx
```

### 인증서 갱신

Let's Encrypt 인증서는 90일마다 갱신이 필요합니다.

#### 수동 갱신

```bash
./renew-cert.sh
```

#### 자동 갱신 (권장)

Linux 서버에서 cron 설정:

```bash
# crontab 편집
crontab -e

# 매일 새벽 2시에 자동 갱신
0 2 * * * /path/to/nginx-rumor-lab/renew-cert.sh >> /var/log/certbot-renew.log 2>&1
```

### 전체 서비스 중지

```bash
docker-compose down
```

## 주요 특징

- **와일드카드 SSL 인증서**: `*.your-domain.com` 형태의 모든 서브도메인에 사용 가능
- **DNS-01 인증**: AWS Route53 DNS를 통한 자동 인증
- **서브도메인별 라우팅**: 각 서브도메인마다 독립적인 설정 파일로 관리
- **리버스 프록시**: 호스트에서 실행 중인 애플리케이션으로 트래픽 전달
- **자동화**: 비대화형 모드로 인증서 자동 발급 및 갱신
- **환경 변수 기반 설정**: `.env` 파일의 도메인 정보로 자동 설정

## 디렉토리 구조

```
.
├── docker-compose.yml              # Docker Compose 설정
├── .env                            # 환경 변수 (gitignore)
├── .env.example                    # 환경 변수 예시
├── renew-cert.sh                   # SSL 인증서 자동 갱신 스크립트
├── nginx/
│   └── conf.d/
│       ├── main.conf.template      # 메인 도메인 + HTTP 리다이렉트
│       ├── app1.conf.template      # app1 서브도메인 설정
│       └── app2.conf.template      # app2 서브도메인 설정
├── certbot/
│   ├── conf/                       # Let's Encrypt 인증서 저장
│   └── logs/                       # Certbot 로그
└── README.md
```

## 문제 해결

### 인증서 발급 실패

- AWS 자격 증명이 올바른지 확인
- Route53에 도메인이 등록되어 있는지 확인
- IAM 사용자가 Route53 권한을 가지고 있는지 확인

### Nginx 시작 실패

- 인증서가 먼저 발급되었는지 확인
- `.env` 파일의 `MY_DOMAIN` 값이 올바른지 확인
- `nginx/conf.d/*.conf` 파일이 정상 생성되었는지 확인

### 502 Bad Gateway 에러

- 호스트에서 애플리케이션이 정상 실행 중인지 확인
- 포트 번호가 nginx 설정과 일치하는지 확인
- `host.docker.internal` 접근이 가능한지 확인 (Linux는 `extra_hosts` 필요)

### Linux에서 host.docker.internal 접근 안됨

docker-compose.yml에 `extra_hosts` 설정이 있는지 확인:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

## 아키텍처

```
인터넷
  ↓ HTTPS
Nginx 컨테이너 (리버스 프록시)
  ↓ host.docker.internal
호스트 머신
  ↓ 포트 3001, 3002, ...
App1, App2 컨테이너 (독립 프로젝트)
```
