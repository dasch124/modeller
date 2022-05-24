FROM fedora 

RUN dnf -y install git tree
WORKDIR /tmp

RUN pwd
RUN git clone https://github.com/dasch124/modeller

RUN chmod +x modeller/build.sh

RUN tree .

RUN modeller/build.sh -a setup
LABEL org.opencontainers.image.source=https://github.com/dasch124/modeller
