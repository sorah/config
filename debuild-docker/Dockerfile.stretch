# See also: https://github.com/sorah/config/blob/master/bin/sorah-debuild
FROM debian:stretch

# just to invalidate cache
ENV NKMIBUILDREV=1

ENV DEBIAN_FRONTEND=noninteractive
RUN mkdir -p /build \
  && apt-get update \
  && apt-get install -y tzdata debhelper dh-make devscripts gnupg2 vim equivs
RUN mkdir -p -m700 /root/.gnupg

