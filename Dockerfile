FROM alpine:3
WORKDIR /app

LABEL version="0.1.2"
LABEL repository="https://github.com/inarix/bookish-happiness"
LABEL homepage="https://github.com/inarix/bookish-happiness"
LABEL maintainer="Alexandre Saison <alexandre.saison@inarix.com>"

RUN apk add ca-certificates curl
COPY sendSlackMessage.sh /app
COPY entrypoint.sh /app

ENTRYPOINT ["sh", "/app/entrypoint.sh"]
