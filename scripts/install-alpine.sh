#!/bin/sh

apk add git
git clone https://github.com/matteocavestri/nscdots.git

./nscdots/usr/sbin/setup-hardware
./nscdots/usr/sbin/setup-desktop-environment
./nscdots/usr/bin/install-nscdots
./nscdots/usr/bin/install-home
