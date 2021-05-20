FROM alpine:3

LABEL version="0.1.2"
LABEL repository="https://github.com/inarix/bookish-happiness"
LABEL homepage="https://github.com/inarix/bookish-happiness"
LABEL maintainer="Alexandre Saison <alexandre.saison@inarix.com>"

RUN apk add ca-certificates curl
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
