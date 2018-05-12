FROM ubuntu

RUN apt-get update && \
    apt-get -y install wget gnupg2 make locales iputils-ping

RUN locale-gen en_US en_US.UTF-8
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && \
    dpkg -i erlang-solutions_1.0_all.deb && \
    apt-get update && \
    apt-get -y install elixir

COPY . /breaking-pp

RUN cd /breaking-pp && make clean prepare deps rel

CMD REPLACE_OS_VARS=true \
    /breaking-pp/_build/prod/rel/breaking_pp/bin/breaking_pp foreground
