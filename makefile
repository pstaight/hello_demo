# Variables
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
CC = gcc
CFLAGS ?= -Wall -g
LDLIBS = -lssl -lcrypto

# Correct directory for local systemd overrides on Ubuntu
SYSTEMDDIR = /etc/systemd/system
CONFDIR = /etc/hello_server
DEPLOYHOOKDIR = /etc/letsencrypt/renewal-hooks/deploy
DOMAIN = polisci.live
SERVICE_USER = hello_server

.PHONY: all clean install uninstall check-deps

all: check-deps hello_server

check-deps:
	@command -v pkg-config >/dev/null && pkg-config --exists openssl 2>/dev/null; \
	if [ $$? -ne 0 ] && [ ! -f /usr/include/openssl/ssl.h ]; then \
		echo "error: OpenSSL development headers not found. Install libssl-dev (Debian/Ubuntu) or openssl-devel (RHEL/Fedora)."; \
		exit 1; \
	fi

hello_server: hello_server.c
	$(CC) $(CFLAGS) hello_server.c -o hello_server $(LDLIBS)

clean:
	rm -f hello_server

# Install target copies files but does NOT enable/start the service automatically.
# Must be run as root (creates a system user, writes to /etc).
install: hello_server hello_server.service hello_server.sh
	@if [ "$$(id -u)" != "0" ]; then \
		echo "error: 'make install' must be run as root (try: sudo make install)"; \
		exit 1; \
	fi

	# 1. Make service user (idempotent - skip if it already exists)
	id -u $(SERVICE_USER) >/dev/null 2>&1 || \
		useradd --system --no-create-home --shell /usr/sbin/nologin $(SERVICE_USER)

	# 2. Make a directory to store the keys
	mkdir -p $(CONFDIR)
	chown -R $(SERVICE_USER):$(SERVICE_USER) $(CONFDIR)

	# 3. Seed the cert/key from the existing Let's Encrypt certificate
	@if [ ! -f /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem ]; then \
		echo "error: /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem not found - run certbot first"; \
		exit 1; \
	fi
	cp /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem $(CONFDIR)/cert.pem
	cp /etc/letsencrypt/live/$(DOMAIN)/privkey.pem $(CONFDIR)/key.pem
	chown $(SERVICE_USER):$(SERVICE_USER) $(CONFDIR)/cert.pem $(CONFDIR)/key.pem
	chmod 640 $(CONFDIR)/key.pem

	# 4. Install the certbot deploy hook so renewals refresh the copy above
	install -D -m 755 hello_server.sh $(DEPLOYHOOKDIR)/hello_server.sh

	# 5. Install binary
	install -D -m 755 hello_server $(DESTDIR)$(BINDIR)/hello_server

	# 6. Install systemd unit file
	install -D -m 644 hello_server.service $(DESTDIR)$(SYSTEMDDIR)/hello_server.service

	@echo "Installed. Run 'systemctl daemon-reload && systemctl enable --now hello_server' to start it."

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/hello_server
	rm -f $(DESTDIR)$(SYSTEMDDIR)/hello_server.service
