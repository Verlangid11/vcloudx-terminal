FROM debian:bookworm-slim

LABEL author="vcloudx" maintainer="vcloudx@gmail.com"

ENV DEBIAN_FRONTEND=noninteractive \
    USER=container \
    HOME=/home/container \
    NODE_INSTALL_DIR=/home/container/node \
    BUN_INSTALL=/usr/local/bun \
    PLAYWRIGHT_BROWSERS_PATH=/usr/local/share/playwright \
    DENO_INSTALL=/usr/local \
    PHP_DEFAULT_VERSION=8.3

ENV PATH="$NODE_INSTALL_DIR/bin:$BUN_INSTALL/bin:/usr/local/go/bin:$DENO_INSTALL/bin:/usr/local/zig:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget git zip unzip tar gzip bzip2 p7zip-full zstd \
        jq nano vim sudo ca-certificates gnupg lsb-release apt-transport-https \
        net-tools iputils-ping dnsutils procps htop iotop iftop \
        build-essential make gcc g++ cmake libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev \
        libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
        ffmpeg imagemagick graphicsmagick webp libwebp-dev \
        mediainfo exiftool gifsicle optipng jpegoptim pngquant \
        sox lame flac vorbis-tools \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p --mode=0755 /usr/share/keyrings \
    && curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | gpg --dearmor > /usr/share/keyrings/cloudflare-public-v2.gpg \
    && echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list \
    && apt-get update && apt-get install -y cloudflared \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
        fonts-liberation fonts-noto-color-emoji libfontconfig1 libfreetype6 \
        libasound2 libgbm1 libgtk-3-0 libnss3 libnspr4 libatk1.0-0 \
        libatk-bridge2.0-0 libcups2 libdrm2 libdbus-1-3 libexpat1 \
        libx11-xcb1 libxcb-dri3-0 libxss1 libxtst6 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list \
    && apt-get update \
    && for VER in 7.4 8.0 8.1 8.2 8.3 8.4; do \
        apt-get install -y --no-install-recommends \
            php${VER} php${VER}-cli php${VER}-common php${VER}-curl \
            php${VER}-mbstring php${VER}-xml php${VER}-zip php${VER}-gd \
            php${VER}-mysql php${VER}-pgsql php${VER}-sqlite3 \
            php${VER}-bcmath php${VER}-intl php${VER}-opcache \
            php${VER}-tokenizer 2>/dev/null || true; \
    done \
    && update-alternatives --set php /usr/bin/php${PHP_DEFAULT_VERSION} 2>/dev/null || true \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://www.python.org/ftp/python/3.13.0/Python-3.13.0.tgz -O /tmp/python.tgz \
    && cd /tmp && tar xzf python.tgz && cd Python-3.13.0 \
    && ./configure --enable-optimizations \
    && make -j$(nproc) altinstall \
    && ln -sf /usr/local/bin/python3.13 /usr/local/bin/python3 \
    && ln -sf /usr/local/bin/pip3.13 /usr/local/bin/pip3 \
    && cd /tmp && rm -rf Python-3.13.0* \
    && pip3 install --upgrade pip setuptools wheel 2>/dev/null || true

RUN apt-get update && apt-get install -y --no-install-recommends \
        ruby ruby-dev bundler \
    && gem install bundler rake \
    && rm -rf /var/lib/apt/lists/*

RUN GO_VER=1.24.0 \
    && wget -q https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz -O /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

RUN ZIG_VER=0.13.0 \
    && wget -q https://ziglang.org/download/${ZIG_VER}/zig-linux-x86_64-${ZIG_VER}.tar.xz -O /tmp/zig.tar.xz \
    && tar -xf /tmp/zig.tar.xz -C /tmp \
    && mv /tmp/zig-linux-x86_64-${ZIG_VER} /usr/local/zig \
    && ln -sf /usr/local/zig/zig /usr/local/bin/zig \
    && rm /tmp/zig.tar.xz

RUN wget -q https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64.zip -O /tmp/bun.zip \
    && unzip -q /tmp/bun.zip -d /tmp \
    && mkdir -p $BUN_INSTALL/bin \
    && mv /tmp/bun-linux-x64/bun $BUN_INSTALL/bin/bun \
    && chmod +x $BUN_INSTALL/bin/bun \
    && rm -rf /tmp/bun-linux-x64* /tmp/bun.zip

RUN curl -fsSL https://deno.land/x/install/install.sh | DENO_INSTALL=/usr/local sh \
    && chmod +x /usr/local/bin/deno

RUN apt-get update && apt-get install -y --no-install-recommends \
        default-jdk \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p $PLAYWRIGHT_BROWSERS_PATH \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest pm2 nodemon pnpm yarn playwright typescript ts-node --loglevel=error \
    && npx playwright install --with-deps chromium \
    && apt-get purge -y nodejs && apt-get autoremove -y \
    && chmod -R 777 $PLAYWRIGHT_BROWSERS_PATH \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home/container container
RUN mkdir -p $NODE_INSTALL_DIR && chown -R container:container $NODE_INSTALL_DIR

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER container
WORKDIR /home/container

CMD ["/bin/bash", "/entrypoint.sh"]
