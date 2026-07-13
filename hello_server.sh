#!/bin/bash
cp /etc/letsencrypt/live/polisci.live/fullchain.pem /etc/hello_server/cert.pem
cp /etc/letsencrypt/live/polisci.live/privkey.pem /etc/hello_server/key.pem
chown hello_server:hello_server /etc/hello_server/cert.pem /etc/hello_server/key.pem
chmod 640 /etc/hello_server/key.pem
systemctl restart hello_server
