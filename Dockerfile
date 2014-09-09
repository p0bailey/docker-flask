
FROM ubuntu:14.04

MAINTAINER Phillip Bailey <phillip@bailey.st>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get -y install  openssh-server nginx vim wget sed python-pip python-dev uwsgi-plugin-python supervisor

RUN sed -i -e 's/without-password/yes/g' /etc/ssh/sshd_config
RUN echo 'root:toor' | chpasswd

COPY requirements.txt /var/www/
RUN pip install -r /var/www/requirements.txt

RUN mkdir -p /var/www/app/static
RUN mkdir -p /var/www/app/templates

RUN mkdir -p /var/log/nginx/app
RUN mkdir -p /var/log/uwsgi/app/


RUN rm /etc/nginx/sites-enabled/default
COPY flask.conf /etc/nginx/sites-available/
RUN ln -s /etc/nginx/sites-available/flask.conf /etc/nginx/sites-enabled/flask.conf
COPY uwsgi.ini /var/www/app/
COPY hello.py /var/www/app/

RUN mkdir -p /var/run/sshd /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf


CMD ["/usr/bin/supervisord"]
