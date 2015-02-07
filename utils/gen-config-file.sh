#!/bin/bash

set -e

CONF_FPATH="$1"
if [ -z "$CONF_FPATH" ]; then
	echo "File path missing."
	exit 1
fi

TTS_URL="http://sandbox.hub.taptinder.org"
if [ ! -z "$2" ]; then
	TTS_URL="$2"
fi

TOKEN_PREFIX=""
if [ ! -z "$3" ]; then
	TOKEN_PREFIX="$3"
fi
if [ ${#TOKEN_PREFIX} -gt 8 ]; then
	echo "Too long (>8) token prefix.";
	exit 1
fi

REG_TOKEN="openTTserver"
if [ ! -z "$4" ]; then
	REG_TOKEN="$4"
fi

LENGTH=`expr 16 - ${#TOKEN_PREFIX}`

CL_TOKEN=${TOKEN_PREFIX}$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $LENGTH | head -n 1)

echo '---' > "$CONF_FPATH"
echo "reg_token: $REG_TOKEN" >> "$CONF_FPATH"
echo "client_token: $CL_TOKEN" >> "$CONF_FPATH"
echo "server_url: $TTS_URL" >> "$CONF_FPATH"

chmod -R u+r,u-wx,go-rwx "$CONF_FPATH"

cat "$CONF_FPATH"