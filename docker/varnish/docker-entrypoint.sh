#!/usr/bin/env sh

set -e

VARNISHD_VCL_PATH=/etc/varnish/default.vcl

# in background
# -S /etc/varnish/secret
#
$(command -v varnishd) -a :80 \
  -T localhost:6082 \
  -f ${VARNISHD_VCL_PATH} \
  -s ${VARNISHD_MEMORY} \
  -P /varnish.pid \
  -p http_max_hdr=128 \
  -p vsl_reclen=4084 \
  -p http_resp_hdr_len=65536 \
  -p http_resp_size=98304 \
  -p workspace_backend=131072


# -D - daemoinize
sh -c '/usr/bin/varnishncsa -b -c -a -F '"'"'{ "host": "'"'${HOSTNAME}'"'", "env": "'"'${ENV}'"'","project": { "code": "%{X-Project}o", "version": "%{X-ProjectVersion}o" }, "@ts":"%{%s}t", "backend": "%{X-Backend}o", "vside": "%{Varnish:side}x", "remoteip":"%h","xforwardedfor":"%{X-Forwarded-For}i","method":"%m","httphost":"%{Host}i","url":"%U","qs": "%q", "httpversion":"%H","status": %s,"bytes": %b, "ref":"%{Referer}i","ua":"%{User-agent}i", "clen": %{Content-Length}o, "bexecms": %{X-Timing}o, "fetcherr": "%{VSL:FetchError}x", "berespms": %{Varnish:time_firstbyte}x,"duration_usec":%D,"cache":"%{Varnish:handling}x","cf_ip": "%{CF-Connecting-IP}i", "cf_user": "%{Cf-Access-Authenticated-User-Email}i", "cf_c": "%{CF-IPCountry}i", "graced": %{X-Graced}i, "metrics": "%{X-Metrics}o", "grace": %{X-Grace}o, "age": %{Age}o, "hits": %{X-Cache}o } '"'"' | sed -e '"'"'s/"\(bytes\|status\|clen\|berespms\|bexecms\|graced\|duration_usec\|age\|hits\|grace\)": -/"\1": 0/g'"'"' '
