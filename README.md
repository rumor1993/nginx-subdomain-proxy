#  Nginx Reverse Proxy with Let's Encrypt Auto-Renewal

[한국어](README.ko.md)

An Nginx reverse proxy server that obtains Let's Encrypt wildcard SSL certificates using AWS Route53 DNS authentication and routes different applications per subdomain.

## Prerequisites

- Docker and Docker Compose installed
- Domain registered in AWS Route53
- AWS IAM user and access key (Route53 permissions required)

## Configuration

### 1. Environment Variables

Copy `.env.example` to `.env` and modify with actual values.

```bash
cp .env.example .env
```

Enter the following information in the `.env` file:

```
AWS_ACCESS_KEY_ID=your_aws_access_key_id
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
AWS_REGION=ap-northeast-2
MY_DOMAIN=your-domain.com
MY_EMAIL=your-email@example.com
```

## Usage

### Initial Setup (Important)

On the first run, you **must run certbot first** to obtain SSL certificates.

#### Step 1: Obtain SSL Certificate with Certbot

```bash
docker-compose run --rm certbot
```

Once the certificate is issued, Let's Encrypt certificates will be stored in the `certbot/conf` directory.

#### Step 2: Start Nginx

```bash
docker-compose up -d nginx
```

Nginx will start and automatically generate configuration files using the `MY_DOMAIN` value from the `.env` file.

### Running Applications

Run each application on the host with port binding:

```bash
# app1 - bind to port 3001
docker run -d -p 3001:3000 your-app1-image

# app2 - bind to port 3002
docker run -d -p 3002:3000 your-app2-image
```

Nginx will proxy to the host's ports via `host.docker.internal`.

### Adding New Subdomains

1. Create a new configuration file:

```bash
# nginx/conf.d/app3.conf.template
cp nginx/conf.d/app1.conf.template nginx/conf.d/app3.conf.template
```

2. Modify the file content:

```nginx
server {
    listen 443 ssl http2;
    server_name app3.${MY_DOMAIN};

    # ... SSL configuration ...

    location / {
        proxy_pass http://host.docker.internal:3003;  # Change port
        # ... proxy headers ...
    }
}
```

3. Restart nginx:

```bash
docker-compose restart nginx
```

### Certificate Renewal

Let's Encrypt certificates need to be renewed every 90 days.

#### Manual Renewal

```bash
./renew-cert.sh
```

#### Automatic Renewal (Recommended)

Set up cron on Linux server:

```bash
# Edit crontab
crontab -e

# Auto-renew daily at 2 AM
0 2 * * * /path/to/nginx-rumor-lab/renew-cert.sh >> /var/log/certbot-renew.log 2>&1
```

### Stop All Services

```bash
docker-compose down
```

## Key Features

- **Wildcard SSL Certificate**: Works with all subdomains like `*.your-domain.com`
- **DNS-01 Authentication**: Automatic authentication via AWS Route53 DNS
- **Subdomain-based Routing**: Manage each subdomain with independent configuration files
- **Reverse Proxy**: Forward traffic to applications running on the host
- **Automation**: Automatic certificate issuance and renewal in non-interactive mode
- **Environment Variable Configuration**: Automatic setup using domain information from `.env` file

## Directory Structure

```
.
├── docker-compose.yml              # Docker Compose configuration
├── .env                            # Environment variables (gitignored)
├── .env.example                    # Environment variable example
├── renew-cert.sh                   # SSL certificate auto-renewal script
├── nginx/
│   └── conf.d/
│       ├── main.conf.template      # Main domain + HTTP redirect
│       ├── app1.conf.template      # app1 subdomain configuration
│       └── app2.conf.template      # app2 subdomain configuration
├── certbot/
│   ├── conf/                       # Let's Encrypt certificates
│   └── logs/                       # Certbot logs
└── README.md
```

## Troubleshooting

### Certificate Issuance Failed

- Verify AWS credentials are correct
- Confirm domain is registered in Route53
- Ensure IAM user has Route53 permissions

### Nginx Startup Failed

- Confirm certificates were issued first
- Verify `MY_DOMAIN` value in `.env` file is correct
- Check if `nginx/conf.d/*.conf` files were generated properly

### 502 Bad Gateway Error

- Verify application is running normally on the host
- Confirm port numbers match nginx configuration
- Verify `host.docker.internal` access is available (Linux requires `extra_hosts`)

### host.docker.internal Not Accessible on Linux

Check if `extra_hosts` is configured in docker-compose.yml:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

## Architecture

```
Internet
  ↓ HTTPS
Nginx Container (Reverse Proxy)
  ↓ host.docker.internal
Host Machine
  ↓ Ports 3001, 3002, ...
App1, App2 Containers (Independent Projects)
```
