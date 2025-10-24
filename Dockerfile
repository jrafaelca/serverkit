FROM ubuntu:24.04

LABEL maintainer="Jose Carrizales <jrafaelca@gmail.com>"

WORKDIR /root

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Zona horaria y policy para evitar intentos de arrancar servicios (en contenedor)
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
 && printf '%s\n' '#!/bin/sh' 'exit 101' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# Instala paquetes que tu provision necesita (incluye rsync, whois, mkpasswd, etc.)
RUN apt-get update && apt-get install -yq \
    openssh-server sudo curl vim \
    build-essential cron make pkg-config \
    sendmail unzip uuid-runtime whois zip rsync openssh-client \
  && mkdir -p /var/run/sshd \
  && apt-get -y autoremove && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# SSH: prepara /root/.ssh (puedes pasar la clave como build-arg o montar)
ARG AUTHORIZED_KEY=""
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
RUN if [ ! -z "$AUTHORIZED_KEY" ]; then echo "$AUTHORIZED_KEY" > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys; fi

# Copia tus scripts /serverkit
COPY src/ /root/serverkit/
RUN chmod -R 755 /root/serverkit

# (Opcional) conserva o genera host keys persistentes: ver instrucciones abajo para mount
EXPOSE 22

# Limpieza: quitar policy-rc.d si quieres (opcional)
# RUN rm -f /usr/sbin/policy-rc.d

CMD ["/usr/sbin/sshd", "-D"]