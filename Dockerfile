# ==========================================
# 阶段一：全栈环境构建 (Build & Runtime)
# ==========================================
# 使用官方推荐的 Python 底座，解决依赖编译问题
FROM python:3.11-alpine3.18

# 1. 设置关键环境变量
#    【核心修复】设置 NODE_PATH，让 PM2 能找到全局安装的 ts-node
ENV QL_DIR=/ql \
    LANG=C.UTF-8 \
    SHELL=/bin/bash \
    PS1="\u@\h:\w \$ " \
    NODE_PATH=/usr/local/lib/node_modules

# 2. 安装系统级依赖
#    安装 build-base, g++, make 确保所有依赖都能编译成功
RUN set -x \
  && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk update \
  && apk add --no-cache bash coreutils git curl wget tzdata perl openssl nodejs jq openssh procps netcat-openbsd unzip npm nginx build-base g++ make python3 \
  && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && echo "Asia/Shanghai" > /etc/timezone

# 3. 安装全局工具
#    安装 pnpm, pm2, ts-node, typescript
RUN npm install -g pnpm@8.3.1 pm2 ts-node typescript

# 4. 准备工作目录
WORKDIR ${QL_DIR}

# 5. 复制后端源码
COPY . ${QL_DIR}

# 6. 处理前端 (直接拉取官方静态资源并去特征)
RUN git clone --depth=1 https://github.com/whyour/qinglong-static.git /ql/static \
    && rm -rf /ql/static/.git \
    && find /ql/static -type f -name "*.html" -exec sed -i 's/青龙/System/g' {} + \
    && find /ql/static -type f -name "*.js" -exec sed -i 's/青龙/System/g' {} +

# 7. 安装项目依赖 (最关键的一步)
#    - 删除 lock 文件，避免版本锁死
#    - pnpm install: 安装所有依赖
#    - pnpm add: 强制在本地再装一遍运行工具，双重保险
RUN rm -f pnpm-lock.yaml \
    && pnpm install \
    && pnpm add -D ts-node typescript

# 8. 处理启动脚本
RUN cp ${QL_DIR}/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh \
    && chmod +x /usr/local/bin/sys-base.sh \
    && mkdir -p ${QL_DIR}/data \
    && mkdir -p /run/nginx

# 9. 暴露端口
EXPOSE 5700

# 10. 启动命令
CMD ["/usr/local/bin/sys-base.sh"]
