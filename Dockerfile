# ==========================================
# 阶段一：全环境构建 (Build & Runtime)
# ==========================================
FROM python:3.11-alpine3.18

# 1. 设置基础环境变量
ENV QL_DIR=/ql \
    LANG=C.UTF-8 \
    SHELL=/bin/bash \
    PS1="\u@\h:\w \$ "

# 2. 安装所有系统依赖
#    【关键修复】安装 build-base 以确保 npm 能编译原生模块
RUN set -x \
  && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk update \
  && apk add --no-cache bash coreutils git curl wget tzdata perl openssl nodejs jq openssh procps netcat-openbsd unzip npm nginx build-base \
  && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && echo "Asia/Shanghai" > /etc/timezone

# 3. 全局安装运行工具
#    【核心修复】补上了 ts-node 和 typescript，这是导致之前报错的罪魁祸首！
RUN npm i -g pnpm@8.3.1 pm2 ts-node typescript

# 4. 准备工作目录
WORKDIR ${QL_DIR}

# 5. 复制后端源码
COPY . ${QL_DIR}

# 6. 处理前端 (直接拉取官方静态资源，避坑)
#    同时把页面上的“青龙”改成“System”
RUN git clone --depth=1 https://github.com/whyour/qinglong-static.git /ql/static \
    && rm -rf /ql/static/.git \
    && find /ql/static -type f -name "*.html" -exec sed -i 's/青龙/System/g' {} + \
    && find /ql/static -type f -name "*.js" -exec sed -i 's/青龙/System/g' {} +

# 7. 安装项目依赖
#    删除 lock 文件防止版本不兼容，重新安装所有依赖
RUN rm -f pnpm-lock.yaml \
    && pnpm install

# 8. 处理启动脚本 (改名去特征)
#    并创建 Nginx 运行所需的目录
RUN cp ${QL_DIR}/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh \
    && chmod +x /usr/local/bin/sys-base.sh \
    && mkdir -p ${QL_DIR}/data \
    && mkdir -p /run/nginx

# 9. 暴露端口
EXPOSE 5700

# 10. 启动命令
CMD ["/usr/local/bin/sys-base.sh"]
