FROM ubuntu:latest

RUN apt-get update && apt-get install -y curl wget inetutils-ping sysbench iproute2