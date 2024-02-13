FROM alpine:3.19.0

ARG TERRAFORM_VERSION=1.7.3

RUN apk update && \
    apk add curl jq python3 bash ca-certificates git openssl openssh unzip wget

RUN cd /tmp && \
    wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/bin

RUN rm -rf /tmp/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /var/tmp/*

ENTRYPOINT ["/usr/bin/terraform"]
CMD ["-help"]