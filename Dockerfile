# ----------------------------------------
# 阶段一：前端源码编译 (Builder)
# ----------------------------------------
FROM node:20-alpine as builder
WORKDIR /app_src

# 1. 安装编译工具
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add --no-cache git python3 make g++

# 2. 复制所有源码
COPY . .

# 3. 【关键修改】改用 npm 安装依赖并编译
#    pnpm 在 Docker 里的兼容性有时不好，npm 更稳定
RUN npm config set registry https://registry.npmmirror.com && \
    npm install && \
    npm run build


# ----------------------------------------
# 阶段二：纯净运行底座 (Runtime)
# ----------------------------------------
FROM alpine:latest
WORKDIR /ql

# 1. 安装纯净的运行环境
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
    bash coreutils git curl wget tzdata \
    nginx python3 py3-pip nodejs npm \
    jq openssl unzip

# 2. 设置环境变量
ENV QL_DIR=/ql \
    QL_BRANCH=develop

# 3. 从 Builder 阶段复制编译好的文件
COPY --from=builder /app_src/back ${QL_DIR}/back
COPY --from=builder /app_src/static ${QL_DIR}/static
COPY --from=builder /app_src/shell ${QL_DIR}/shell

# 4. 复制并重命名启动脚本 (去特征)
COPY --from=builder /app_src/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh

# 5. 安装后端依赖 (同样改用 npm)
COPY --from=builder /app_src/package.json ${QL_DIR}/
RUN cd ${QL_DIR} && npm install --production

# 6. 权限与时区
RUN chmod +x /usr/local/bin/sys-base.sh && \
    mkdir -p ${QL_DIR}/data && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 7. 暴露端口
EXPOSE 7860

# 8. 默认启动命令
CMD ["/usr/local/bin/sys-base.sh"]
