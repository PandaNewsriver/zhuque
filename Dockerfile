# ==========================================
# 终极策略：继承官方 + 智能防报错
# ==========================================
FROM whyour/qinglong:latest

ENV QL_DIR=/ql
WORKDIR ${QL_DIR}

# 1. 【去特征】+【强制修改端口】
#    核心修改：加了 if [ -d ... ] 判断
#    不管 /etc/nginx 存不存在，都不会报错了
RUN rm -rf .git \
    && find /ql/static -type f -name "*.html" -exec sed -i 's/青龙/System/g' {} + \
    && find /ql/static -type f -name "*.js" -exec sed -i 's/青龙/System/g' {} + \
    # 修复点：如果目录不存在，直接跳过，防止报错中断
    && if [ -d "/etc/nginx" ]; then find /etc/nginx -type f -name "*.conf" -exec sed -i 's/5700/7860/g' {} +; fi \
    # 继续修改其他配置
    && find /ql -type f -name "*.conf" -exec sed -i 's/5700/7860/g' {} + \
    && sed -i 's/5700/7860/g' /ql/docker/docker-entrypoint.sh

# 2. 处理启动脚本
RUN cp /ql/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh \
    && chmod +x /usr/local/bin/sys-base.sh

# 3. 暴露 7860 端口
EXPOSE 7860

# 4. 启动
CMD ["/usr/local/bin/sys-base.sh"]
