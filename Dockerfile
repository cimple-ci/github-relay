FROM progrium/busybox

ARG CIMPLE_GITHUB_RELAY_VERSION

ENTRYPOINT ["cimple-github-relay"]

ENV PATH /opt/cimple/bin:$PATH

COPY ./output/downloads/$CIMPLE_GITHUB_RELAY_VERSION/cimple-github-relay_${CIMPLE_GITHUB_RELAY_VERSION}_linux_amd64.tar.gz /tmp/cimple-github-relay_linux_amd64.tar.gz

RUN cd /tmp \
    && zcat cimple-github-relay_linux_amd64.tar.gz | tar -xvf - \
    && chmod +x cimple-github-relay \
    && mkdir -p /opt/cimple/bin \
    && mv cimple-github-relay /opt/cimple/bin \
    && rm -rf /tmp/*
