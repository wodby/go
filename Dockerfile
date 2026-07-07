ARG GO_VER=1.26.4

FROM golang:${GO_VER}-alpine

ARG GO_DEV

ARG WODBY_USER_ID=1000
ARG WODBY_GROUP_ID=1000

ENV GO_DEV="${GO_DEV}" \
    SSHD_PERMIT_USER_ENV="yes"

ENV APP_ROOT="/usr/src/app" \
    CONF_DIR="/usr/src/conf" \
    FILES_DIR="/mnt/files" \
    SSHD_HOST_KEYS_DIR="/etc/ssh" \
    ENV="/home/wodby/.shrc" \
    GOPATH="/home/wodby/go" \
    GOCACHE="/home/wodby/.cache/go-build" \
    GOMODCACHE="/home/wodby/go/pkg/mod" \
    \
    GIT_USER_EMAIL="wodby@example.com" \
    GIT_USER_NAME="wodby"

ENV PATH="${GOPATH}/bin:${PATH}"

ARG TARGETPLATFORM

RUN set -xe; \
    \
    # Delete existing user/group if uid/gid occupied. \
    existing_group=$(getent group "${WODBY_GROUP_ID}" | cut -d: -f1); \
    if [[ -n "${existing_group}" ]]; then delgroup "${existing_group}"; fi; \
    existing_user=$(getent passwd "${WODBY_USER_ID}" | cut -d: -f1); \
    if [[ -n "${existing_user}" ]]; then deluser "${existing_user}"; fi; \
    \
    addgroup -g "${WODBY_GROUP_ID}" -S wodby; \
    adduser -u "${WODBY_USER_ID}" -D -S -s /bin/bash -G wodby wodby; \
    sed -i '/^wodby/s/!/*/' /etc/shadow; \
    \
    apk add --update --no-cache -t .wodby-go-run-deps \
        bash \
        ca-certificates \
        curl \
        git \
        gzip \
        less \
        make \
        mariadb-client \
        mariadb-connector-c \
        nano \
        openssh \
        openssh-client \
        patch \
        postgresql-client \
        rabbitmq-c \
        rsync \
        su-exec \
        sudo \
        tar \
        tig \
        tmux \
        tzdata \
        unzip \
        wget \
        yaml; \
    \
    if [[ -n "${GO_DEV}" ]]; then \
        apk add --update --no-cache -t .wodby-go-dev-deps \
            build-base \
            gcc \
            linux-headers \
            mariadb-dev \
            musl-dev \
            postgresql-dev; \
    fi; \
    \
    # Download helper scripts. \
    dockerplatform=${TARGETPLATFORM:-linux/amd64}; \
    gotpl_url="https://github.com/wodby/gotpl/releases/latest/download/gotpl-${dockerplatform/\//-}.tar.gz"; \
    wget -qO- "${gotpl_url}" | tar xz --no-same-owner -C /usr/local/bin; \
    git clone https://github.com/wodby/alpine /tmp/alpine; \
    cd /tmp/alpine; \
    latest=$(git describe --abbrev=0 --tags); \
    git checkout "${latest}"; \
    mv /tmp/alpine/bin/* /usr/local/bin; \
    \
    # Install redis-cli. \
    apk add --update --no-cache redis; \
    mv /usr/bin/redis-cli /tmp/; \
    apk del --purge redis; \
    deluser redis; \
    mv /tmp/redis-cli /usr/bin; \
    \
    install -o wodby -g wodby -d \
        "${APP_ROOT}" \
        "${CONF_DIR}" \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private" \
        "${GOPATH}/bin" \
        "${GOMODCACHE}" \
        "${GOCACHE}" \
        /home/wodby/.ssh; \
    \
    { \
        echo 'export PS1="\u@${WODBY_APP_NAME:-go}.${WODBY_ENVIRONMENT_NAME:-container}:\w $ "'; \
        echo "export PATH=${PATH}"; \
    } | tee /home/wodby/.shrc; \
    \
    cp /home/wodby/.shrc /home/wodby/.bashrc; \
    cp /home/wodby/.shrc /home/wodby/.bash_profile; \
    \
    # Configure sudoers. \
    { \
        echo "Defaults secure_path=\"$PATH\""; \
        echo 'Defaults env_keep += "APP_ROOT FILES_DIR GOPATH GOCACHE GOMODCACHE"'; \
        \
        if [[ -n "${GO_DEV}" ]]; then \
            echo 'wodby ALL=(root) NOPASSWD:SETENV:ALL'; \
        else \
            echo -n 'wodby ALL=(root) NOPASSWD:SETENV: '; \
            echo -n '/usr/local/bin/gen_ssh_keys, '; \
            echo -n '/usr/local/bin/init_container, '; \
            echo -n '/usr/sbin/sshd, '; \
            echo '/usr/sbin/crond'; \
        fi; \
    } | tee /etc/sudoers.d/wodby; \
    \
    touch /etc/ssh/sshd_config; \
    chown wodby:wodby /etc/ssh/sshd_config /home/wodby/.*; \
    \
    rm -rf \
        /etc/crontabs/root \
        /tmp/* \
        /var/cache/apk/*

USER wodby

WORKDIR ${APP_ROOT}
EXPOSE 8080

COPY templates /etc/gotpl/
COPY docker-entrypoint.sh /
COPY bin /usr/local/bin/

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["go"]
