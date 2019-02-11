FROM alpine:edge

# Basic tests requirements
RUN apk add --no-cache curl git docker jq sudo bash

RUN git clone https://github.com/hchenxa/bats.git &&\
    bats/install.sh /usr/local


COPY run.sh helpers.bash install_ui_tools.sh imagepolicy.yaml  /tests/
COPY suites /tests/suites


ENV PATH /usr/local/bin:$PATH

ENV IN_DOCKER yes

WORKDIR /tests
