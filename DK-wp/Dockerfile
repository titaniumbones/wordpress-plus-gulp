FROM visiblevc/wordpress:latest
# ENV TERM=xterm
LABEL maintainer="Matt Price <matt.price@utoronto.ca>" \
      version="0.1"

# Install base requirements & sensible defaults + required PHP extensions
# RUN echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list \
#     && curl -seb.nodesource.com/setup_6.x | bash - \
RUN apt-get update \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-utils \
        git \
    && curl -s -o /wait-for-it.sh \
       https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh \
    && chmod a+x /wait-for-it.sh

COPY ./run-wp.sh /run-wp.sh

RUN  chmod +x /run-wp.sh \
     && mkdir -p /local-scripts /wordpress/wp-content/themes  \
     && rm /var/www/html \
     && ln -s /wordpress /var/www/html
     


WORKDIR /wordpress
EXPOSE 80 443
CMD ["/run-wp.sh"]
