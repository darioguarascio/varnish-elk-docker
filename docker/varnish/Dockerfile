FROM    alpine:3.13.6

ARG     VARNISH_VERSION




RUN     set -x && \
        apk add --no-cache --upgrade varnish=${VARNISH_VERSION} && \
        apk add jq && \
        rm -rf /tmp/* /var/cache/apk/*


COPY    ./*.vcl /usr/share/varnish/vcl/
COPY    ./default.vcl /etc/varnish/default.vcl
COPY    ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint


#HEALTHCHECK --interval=10s --timeout=3s \
#  CMD test -e /proc/`cat /varnish.pid` || exit 1


CMD     ["/usr/local/bin/docker-entrypoint"]





