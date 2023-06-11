FROM  --platform=arm64 nickblah/lua:5.3-luarocks-alpine
RUN apk add --no-cache build-base
RUN apk add --no-cache openssl
RUN apk add --no-cache libressl-dev
RUN apk add --no-cache bind-tools
RUN apk add --no-cache git
RUN apk add --no-cache wget
RUN git config --global url."https://github.com/".insteadOf git@github.com:
RUN git config --global url."https://".insteadOf git://
RUN luarocks install luasocket \
    && luarocks install luasec \
    && luarocks install copas \
    && luarocks install luafilesystem \
    && luarocks install mobdebug

CMD [ "/bin/sh" ]