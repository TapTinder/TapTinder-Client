#!/bin/bash

for ((i=1;1;i++)); do
    perl ./ttclient.pl $@
    if [ ! -f './.do_ttclient_upgrade' ]; then
        exit;
    fi
    echo "Trying to do client upgrade with 'git pull'."
    git pull || exit
done
