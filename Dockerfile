# ----------------------------------------
# 阶段一：前端源码编译 (Builder)
# ----------------------------------------
FROM node:20-alpine as builder
WORKDIR /app_src

# 1. 安装编译工具 (jq用于修改json文件)
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add --no-cache git python3 make g++ jq

# 2. 复制源码
COPY . .

# 3. 【核心黑科技】强制解除 pnpm 限制，改用 npm
#    - 删除 pnpm-lock.yaml (防止冲突)
#    - 删除 package.json 里的 preinstall 脚本 (解除"只能用pnpm"的锁)
#    - 使用 npm 安装并编译
RUN rm -f pnpm-lock.yaml && \
    npm pkg delete scripts.preinstall && \
    npm config set registry https://registry.npmmirror.com && \
    npm install && \
    npm run build


# ----------------------------------------
# 阶段二：纯净运行底座 (Runtime)
# ----------------------------------------
FROM alpine:latest
WORKDIR /ql

# 1. 安装运行环境
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
    bash coreutils git curl wget tzdata \
    nginx python3 py3-pip nodejs npm \
    jq openssl unzip

# 2. 环境变量
ENV QL_DIR=/ql \
    QL_BRANCH=develop

# 3. 复制编译产物
COPY --from=builder /app_src/back ${QL_DIR}/back
COPY --from=builder /app_src/static ${QL_DIR}/static
COPY --from=builder /app_src/shell ${QL_DIR}/shell
COPY --from=builder /app_src/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh

# 4. 安装后端依赖 (同样使用 npm)
COPY --from=builder /app_src/package.json ${QL_DIR}/
#    这里只安装生产环境依赖，且同样需要移除限制
RUN cd ${QL_DIR} && \
    npm pkg delete scripts.preinstall && \
    npm install --production

# 5. 补充安装 pnpm (虽然我们用 npm 构建，但保留 pnpm 预防部分脚本需要)
RUN npm install -g pnpm

# 6. 权限与端口
RUN chmod +x /usr/local/bin/sys-base.sh && \
    mkdir -p ${QL_DIR}/data && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

EXPOSE 7860
CMD ["/usr/local/bin/sys-base.sh"]
