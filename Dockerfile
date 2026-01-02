# ==========================================
# 阶段一：依赖安装 (Builder)
# ==========================================
FROM python:3.11-alpine3.18 AS builder

# 1. 安装基础工具
RUN set -x \
  && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk update \
  && apk add nodejs npm git build-base \
  # 【修复1】这里补上了 pm2
  && npm i -g pnpm@8.3.1 pm2

# 2. 复制依赖文件并安装
WORKDIR /tmp/build
COPY package.json .npmrc pnpm-lock.yaml ./
RUN pnpm install --prod

# ==========================================
# 阶段二：最终镜像 (Runtime)
# ==========================================
FROM python:3.11-alpine3.18

ENV QL_DIR=/ql \
    LANG=C.UTF-8 \
    SHELL=/bin/bash \
    PS1="\u@\h:\w \$ "

# 1. 安装运行环境
#    【修复2】这里补上了 nginx，并确保安装 pm2
RUN set -x \
  && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk update \
  && apk add --no-cache bash coreutils git curl wget tzdata perl openssl nodejs jq openssh procps netcat-openbsd unzip npm nginx \
  && npm i -g pm2 \
  && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && echo "Asia/Shanghai" > /etc/timezone

# 2. 处理前端文件 (拉取静态资源并去特征)
RUN git clone --depth=1 https://github.com/whyour/qinglong-static.git /ql/static \
    && rm -rf /ql/static/.git \
    && find /ql/static -type f -name "*.html" -exec sed -i 's/青龙/System/g' {} + \
    && find /ql/static -type f -name "*.js" -exec sed -i 's/青龙/System/g' {} +

# 3. 复制后端源码
WORKDIR ${QL_DIR}
COPY . ${QL_DIR}

# 4. 从 Builder 复制依赖
COPY --from=builder /tmp/build/node_modules/. /ql/node_modules/

# 5. 处理启动脚本
RUN cp ${QL_DIR}/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh \
    && chmod +x /usr/local/bin/sys-base.sh \
    && mkdir -p ${QL_DIR}/data

# 6. 配置 Nginx (确保它存在)
RUN mkdir -p /run/nginx

EXPOSE 5700

CMD ["/usr/local/bin/sys-base.sh"]
