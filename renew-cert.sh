#!/bin/bash

# SSL 인증서 자동 갱신 스크립트
# cron으로 주기적으로 실행하여 인증서를 갱신하고 nginx를 재시작

# 스크립트가 위치한 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# certbot으로 인증서 갱신 시도 (30일 이내 만료시에만 갱신)
docker-compose run --rm certbot renew

# 갱신 성공 시 nginx 재시작하여 새 인증서 적용
if [ $? -eq 0 ]; then
    echo "Certificate renewal successful. Reloading nginx..."
    docker-compose exec nginx nginx -s reload
else
    echo "Certificate renewal failed or not needed yet."
fi
