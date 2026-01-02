# ==========================================
# 阶段一：依赖安装 (Builder)
# ==========================================
FROM python:3.11-alpine3.18 AS builder

# 1. 安装基础工具和指定版本的 pnpm
#    (严格按照你提供的成功案例配置)
RUN set -x \
  && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk update \
  && apk add nodejs npm git build-base \
  && npm i -g pnpm@8.3.1

# 2. 复制依赖文件并安装
#    只安装生产环境依赖 (--prod)，跳过所有会导致报错的开发依赖
WORKDIR /tmp/build
COPY package.json .npmrc pnpm-lock.yaml ./
RUN pnpm install --prod

# ==========================================
# 阶段二：最终镜像 (Runtime)
# ==========================================
FROM python:3.11-alpine3.18

# 1. 设置环境变量 (保持兼容性，但隐藏特征)
ENV QL_DIR=/ql \
    LANG=C.UTF-8 \
    SHELL=/bin/bash \
    PS1="\u@\h:\w \$ "

# 2. 安装运行环境
RUN set -x \
  && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk update \
  && apk add --no-cache bash coreutils git curl wget tzdata perl openssl nodejs jq openssh procps netcat-openbsd unzip npm \
  && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && echo "Asia/Shanghai" > /etc/timezone

# 3. 处理前端文件 (关键步骤！)
#    不自己编译，直接拉取官方做好的静态页面，然后用命令“整容”
RUN git clone --depth=1 https://github.com/whyour/qinglong-static.git /ql/static \
    && rm -rf /ql/static/.git \
    # 【整容手术】把页面里的“青龙”字样全部替换掉
    && find /ql/static -type f -name "*.html" -exec sed -i 's/青龙/System/g' {} + \
    && find /ql/static -type f -name "*.js" -exec sed -i 's/青龙/System/g' {} +

# 4. 复制你的后端源码 (使用 COPY 而不是 git clone，保证是你自己的代码)
WORKDIR ${QL_DIR}
COPY . ${QL_DIR}

# 5. 从第一阶段复制安装好的依赖
COPY --from=builder /tmp/build/node_modules/. /ql/node_modules/

# 6. 处理启动脚本 (改名去特征)
#    把 docker-entrypoint.sh 改名为 sys-base.sh
RUN cp ${QL_DIR}/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh \
    && chmod +x /usr/local/bin/sys-base.sh \
    && mkdir -p ${QL_DIR}/data

# 7. 暴露端口
EXPOSE 5700

# 8. 启动
CMD ["/usr/local/bin/sys-base.sh"]
