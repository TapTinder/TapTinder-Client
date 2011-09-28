
for ((i=1;1;i++)); do
    perl ./ttclient.pl $@
    if [ ! -f './.do_ttclient_upgrade' ]; then
        exit;
    fi
    echo "Trying to do client upgrade with 'svn up ..'."
    svn up .. || exit
done
