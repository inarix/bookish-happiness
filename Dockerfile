FROM python:3-alpine

LABEL version="0.1.2"
LABEL repository="https://github.com/inarix/bookish-happiness"
LABEL homepage="https://github.com/inarix/bookish-happiness"
LABEL maintainer="Alexandre Saison <alexandre.saison@inarix.com>"

RUN apk add --no-cache ca-certificates curl jq build-base bash
RUN pip install requests

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
