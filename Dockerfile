FROM progrium/busybox

COPY output/cimple-github-relay /opt/cimple-github-relay
RUN chmod +x /opt/cimple-github-relay

ENTRYPOINT ["/opt/cimple-github-relay"]
