# JuggleIM on Railway: upstream juggleim/im-server (Apache-2.0) built from source at a pinned commit, binary unmodified.
# Railway layer: a Caddy front door on port 8080 that path-routes to the four internal listeners (WebSocket 9003,
# server API 9001, navigator 9002, admin console 8090), and a start script that renders the config from env vars,
# initialises the MySQL schema on first boot, replaces the default admin/123456 password with a generated one,
# sets a per-deploy admin JWT secret and registers the public WSS address for client SDKs.
ARG IMSERVER_COMMIT=c01fa241723bfb41fa882ac62134ec5f390a9908

FROM golang:1.25.12-alpine AS builder
ARG IMSERVER_COMMIT
RUN apk add --no-cache git
RUN git clone https://github.com/juggleim/im-server /src && cd /src && git checkout ${IMSERVER_COMMIT}
WORKDIR /src
RUN go mod download
RUN cd launcher && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/imserver main.go

FROM alpine:3.20
LABEL org.opencontainers.image.source="https://github.com/onepush-dev/juggleim"
RUN apk add --no-cache bash tzdata ca-certificates caddy mysql-client mariadb-connector-c \
    && mkdir -p /opt/conf /opt/logs /opt/sql
WORKDIR /opt
COPY --from=builder /out/imserver /opt/imserver
COPY railway/imserver.sql /opt/sql/imserver.sql
COPY railway/Caddyfile /etc/caddy/Caddyfile
COPY railway/start.sh /opt/railway-start.sh
RUN chmod +x /opt/imserver /opt/railway-start.sh
ENV MYSQL_PORT=3306 \
    MYSQL_DB_NAME=jim_db \
    MYSQL_USER=root \
    JUGGLEIM_ADMIN_USER=admin
EXPOSE 8080
ENTRYPOINT ["/opt/railway-start.sh"]
