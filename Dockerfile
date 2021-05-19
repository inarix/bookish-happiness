FROM node:12.0.0-slim
WORKDIR /app

LABEL version="0.1.0"
LABEL repository="https://github.com/inarix/bookish-happiness"
LABEL homepage="https://github.com/inarix/bookish-happiness"
LABEL maintainer="Alexandre Saison <alexandre.saison@inarix.com>"

COPY ./entrypoint.sh /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]


