#!/bin/bash

DIR='/home/jurosz'
SRCDIR=$DIR/dev-tt
DESTDIR=$DIR/dev-tt-paral

if [ ! -d $SRCDIR/client ]; then
  echo "Source directory '$SRCDIR/client' not found."
  exit
fi

if [ ! -d $SRCDIR/client-conf ]; then
  echo "Source directory '$SRCDIR/client-conf' not found."
  exit
fi

if [ ! -d $DESTDIR ]; then
  echo "Destination directory '$DESTDIR' not found."
  exit
fi

if [ ! -d $DESTDIR/client-data-base ]; then
  echo "Destination directory '$DESTDIR/client-data-base' not found."
  exit
fi

rsync -aH --delete $SRCDIR/client/ $DESTDIR/cl-dir1/client
rsync -aH --delete $SRCDIR/client-conf/ $DESTDIR/cl-dir1/client-conf
rsync -aH --delete $DESTDIR/client-data-base/ $DESTDIR/cl-dir1/client-data

rsync -aH --delete $SRCDIR/client/ $DESTDIR/cl-dir2/client
rsync -aH --delete $SRCDIR/client-conf/ $DESTDIR/cl-dir2/client-conf
rsync -aH --delete $DESTDIR/client-data-base/ $DESTDIR/cl-dir2/client-data

rsync -aH --delete $SRCDIR/client/ $DESTDIR/cl-dir3/client
rsync -aH --delete $SRCDIR/client-conf/ $DESTDIR/cl-dir3/client-conf
rsync -aH --delete $DESTDIR/client-data-base/ $DESTDIR/cl-dir3/client-data

rsync -aH --delete $SRCDIR/client/ $DESTDIR/cl-dir4/client
rsync -aH --delete $SRCDIR/client-conf/ $DESTDIR/cl-dir4/client-conf
rsync -aH --delete $DESTDIR/client-data-base/ $DESTDIR/cl-dir4/client-data

TTCMD='perl ttclient.pl --end_after_no_new_job';

cd $DESTDIR/cl-dir1/client ; $TTCMD 2>&1 > $DESTDIR/cl1-out.txt &
cd $DESTDIR/cl-dir2/client ; $TTCMD 2>&1 > $DESTDIR/cl2-out.txt &
cd $DESTDIR/cl-dir3/client ; $TTCMD 2>&1 > $DESTDIR/cl3-out.txt &
cd $DESTDIR/cl-dir4/client ; $TTCMD 2>&1 > $DESTDIR/cl4-out.txt &

cd $SRCDIR/client
ps -a | grep 'perl ttclient.pl -end' | grep -v grep
