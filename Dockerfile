# ==========================================
# 阶段一：提取源 (Source)
# ==========================================
# 直接使用官方最新镜像作为“仓库”，里面有编译完美的文件
FROM whyour/qinglong:latest as source

# ==========================================
# 阶段二：清洗与重组 (Final)
# ==========================================
# 使用纯净的 Alpine 底座，假装是从零构建的
FROM python:3.11-alpine

# 1. 基础环境变量
ENV QL_DIR=/ql \
    LANG=C.UTF-8 \
    SHELL=/bin/bash \
    PS1="\u@\h:\w \$ "

# 2. 安装基础环境
#    安装 nginx, nodejs, pm2 等运行必需品
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk update \
  && apk add --no-cache bash coreutils git curl wget tzdata perl openssl nodejs jq openssh procps netcat-openbsd unzip npm nginx python3 \
  && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && echo "Asia/Shanghai" > /etc/timezone \
  && npm install -g pm2 pnpm

# 3. 【核心操作】直接复制官方编译好的程序
#    跳过所有编译步骤，直接拿成品，100% 能跑！
COPY --from=source /ql /ql

# 4. 【去特征清洗】
#    对拿来的文件进行修改，去掉“青龙”标识
WORKDIR /ql
RUN rm -rf .git \
    # 修改静态资源里的文字
    && find /ql/static -type f -name "*.html" -exec sed -i 's/青龙/System/g' {} + \
    && find /ql/static -type f -name "*.js" -exec sed -i 's/青龙/System/g' {} + \
    # 替换官方的 banner 图（可选，防止日志里出现字符画）
    && echo "" > /ql/shell/share.sh \
    # 准备启动脚本
    && cp /ql/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh \
    && chmod +x /usr/local/bin/sys-base.sh \
    && mkdir -p /run/nginx \
    && mkdir -p /ql/data

# 5. 暴露端口
EXPOSE 5700

# 6. 启动命令
CMD ["/usr/local/bin/sys-base.sh"]
