# ==========================================
# 终极策略：继承官方 + 强制改端口
# ==========================================
FROM whyour/qinglong:latest

ENV QL_DIR=/ql
WORKDIR ${QL_DIR}

# 1. 【去特征】+【强制修改端口】
#    sed -i ... 5700/7860 : 把所有配置文件里的 5700 全部改成 7860
#    这样做完，镜像天生就是 7860 端口，不再需要启动脚本去改
RUN rm -rf .git \
    && find /ql/static -type f -name "*.html" -exec sed -i 's/青龙/System/g' {} + \
    && find /ql/static -type f -name "*.js" -exec sed -i 's/青龙/System/g' {} + \
    && find /etc/nginx -type f -name "*.conf" -exec sed -i 's/5700/7860/g' {} + \
    && find /ql -type f -name "*.conf" -exec sed -i 's/5700/7860/g' {} + \
    && sed -i 's/5700/7860/g' /ql/docker/docker-entrypoint.sh

# 2. 处理启动脚本
RUN cp /ql/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh \
    && chmod +x /usr/local/bin/sys-base.sh

# 3. 暴露 7860 端口 (告诉 HF 我们用这个)
EXPOSE 7860

# 4. 启动
CMD ["/usr/local/bin/sys-base.sh"]
