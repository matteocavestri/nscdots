#!/bin/sh

apk add git
mkdir -p /tmp/nscdots
git clone https://github.com/matteocavestri/nscdots.git /tmp/nscdots

./tmp/nscdots/usr/sbin/setup-hardware
./tmp/nscdots/usr/sbin/setup-desktop-environment
./tmp/nscdots/usr/bin/install-nscdots
./tmp/nscdots/usr/bin/install-home
