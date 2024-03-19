FROM jetbrains/teamcity-server:latest

USER root

COPY ["rootfs", "/"]

RUN chown -R tcuser:tcuser /opt/teamcity \
 && chmod -R 0644 /opt/teamcity/datadir

USER tcuser

WORKDIR /

ENTRYPOINT [ "/run-services.sh" ]