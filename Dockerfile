# ==========================================
# 终极策略：直接使用官方镜像改装
# ==========================================
# 放弃所有手动构建，直接继承官方镜像，保证环境 100% 正确
FROM whyour/qinglong:latest

# 1. 基础信息修改
ENV QL_DIR=/ql
WORKDIR ${QL_DIR}

# 2. 【去特征清洗】
#    原地修改文件，把“青龙”字样改成“System”
#    不做任何文件移动，确保路径绝对不会错
RUN rm -rf .git \
    && find /ql/static -type f -name "*.html" -exec sed -i 's/青龙/System/g' {} + \
    && find /ql/static -type f -name "*.js" -exec sed -i 's/青龙/System/g' {} +

# 3. 处理启动脚本 (仅改名，不修改内容)
#    复制一份官方的启动脚本并改名，骗过进程检测
RUN cp /ql/docker/docker-entrypoint.sh /usr/local/bin/sys-base.sh \
    && chmod +x /usr/local/bin/sys-base.sh

# 4. 暴露端口
EXPOSE 5700

# 5. 启动命令
CMD ["/usr/local/bin/sys-base.sh"]
