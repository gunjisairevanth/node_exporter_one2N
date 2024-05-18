FROM ubuntu:20.04
# RUN apt curl
RUN apt-get update && apt-get install -y curl bc
COPY run.sh /app/
RUN chmod +x /app/run.sh
# CMD ["/bin/sh", "sleep 3600"]
CMD ["sh", "-c", "/app/run.sh"]