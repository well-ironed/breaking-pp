FROM ubuntu

ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
RUN apt-get update && \
    apt-get -y install wget gnupg2 git make locales iputils-ping \
               erlang-base erlang-tools erlang-inets unzip && \
    locale-gen en_US en_US.UTF-8 && \
    cd /usr && wget https://github.com/elixir-lang/elixir/releases/download/v1.6.6/Precompiled.zip && unzip Precompiled.zip

COPY . /breaking-pp

RUN cd /breaking-pp && make clean prepare deps rel

CMD REPLACE_OS_VARS=true \
    /breaking-pp/_build/prod/rel/breaking_pp/bin/breaking_pp foreground
