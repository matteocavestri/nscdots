#!/bin/sh

apk add git
git clone https://github.com/matteocavestri/nscdots.git /tmp

./tmp/nscdots/usr/sbin/setup-hardware
./tmp/ncsdots/usr/sbin/setup-desktop-environment
./tmp/ncsdots/usr/bin/install-nscdots
./tmp/ncsdots/usr/bin/install-home
