# ----------------------------------------
# 阶段一：前端源码编译 (Builder)
# ----------------------------------------
# 这一步是中间过程，用来把 src 里的代码编译成网页
FROM node:20-alpine as builder
WORKDIR /app_src

# 1. 安装编译工具
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add --no-cache git python3 make g++

# 2. 复制依赖描述文件
COPY package.json pnpm-lock.yaml .npmrc ./
#    使用淘宝源加速
RUN npm config set registry https://registry.npmmirror.com && \
    npm install -g pnpm && \
    pnpm install

# 3. 复制所有源码并开始编译
COPY . .
RUN pnpm build


# ----------------------------------------
# 阶段二：纯净运行底座 (Runtime)
# ----------------------------------------
# 最终产出的镜像，基于 Alpine，没有任何 whyour 的痕迹
FROM alpine:latest
WORKDIR /ql

# 1. 安装纯净的运行环境
#    去除了官方 Dockerfile 里可能存在的冗余信息
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
    bash coreutils git curl wget tzdata \
    nginx python3 py3-pip nodejs npm \
    jq openssl unzip

# 2. 设置环境变量 (保持 /ql 路径以兼容代码逻辑，但外界看不出)
ENV QL_DIR=/ql \
    QL_BRANCH=develop

# 3. 从 Builder 阶段“偷”走编译好的文件
COPY --from=builder /app_src/back ${QL_DIR}/back
COPY --from=builder /app_src/static ${QL_DIR}/static
COPY --from=builder /app_src/shell ${QL_DIR}/shell

# 4. 【关键去特征操作】
#    复制 docker/docker-entrypoint.sh 但重命名为 sys-base.sh
#    这样在进程列表里看到的就是 sys-base.sh，而不是 docker-entrypoint
COPY --from=builder /app_src/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh

# 5. 安装后端依赖
COPY --from=builder /app_src/package.json ${QL_DIR}/
COPY --from=builder /app_src/pnpm-lock.yaml ${QL_DIR}/
RUN cd ${QL_DIR} && npm install -g pnpm && pnpm install --prod

# 6. 权限与时区
RUN chmod +x /usr/local/bin/sys-base.sh && \
    mkdir -p ${QL_DIR}/data && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 7. 暴露端口
EXPOSE 7860

# 8. 启动命令 (指向我们改名后的脚本)
CMD ["/usr/local/bin/sys-base.sh"]
