FROM alpine:3
WORKDIR /app

LABEL version="0.1.0"
LABEL repository="https://github.com/inarix/bookish-happiness"
LABEL homepage="https://github.com/inarix/bookish-happiness"
LABEL maintainer="Alexandre Saison <alexandre.saison@inarix.com>"

RUN apk add ca-certificates

COPY ./sendSlackMessage.sh /app/sendSlackMessage.sh
COPY ./functions.sh /app/functions.sh
COPY ./entrypoint.sh /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]