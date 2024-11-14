FROM ubuntu:22.04

RUN apt-get -y update && apt-get -y install ca-certificates

RUN mkdir -p /opt
COPY typosearch-server /opt
RUN chmod +x /opt/typosearch-server
EXPOSE 8108
ENTRYPOINT ["/opt/typosearch-server"]