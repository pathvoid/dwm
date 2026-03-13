# dwm - dynamic window manager
# See LICENSE file for copyright and license details.

include config.mk

SRC = drw.c dwm.c util.c
OBJ = ${SRC:.c=.o}

all: dwm

.c.o:
	${CC} -c ${CFLAGS} $<

${OBJ}: config.h config.mk

config.h:
	cp config.def.h $@

dwm: ${OBJ}
	${CC} -o $@ ${OBJ} ${LDFLAGS}

clean:
	rm -f dwm ${OBJ} *.orig *.rej

install: all
	mkdir -p ${DESTDIR}${PREFIX}/bin
	install -Dm755 dwm ${DESTDIR}${PREFIX}/bin/dwm
	mkdir -p ${DESTDIR}${MANPREFIX}/man1
	sed "s/VERSION/${VERSION}/g" < dwm.1 > ${DESTDIR}${MANPREFIX}/man1/dwm.1
	chmod 644 ${DESTDIR}${MANPREFIX}/man1/dwm.1
	mkdir -p /usr/share/xsessions/
	test -f /usr/share/xsessions/dwm.desktop || install -Dm644 dwm.desktop /usr/share/xsessions/
	install -Dm644 .xinitrc /home/${SUDO_USER}/.xinitrc
	# Install config.h for keybinds script
	mkdir -p /home/${SUDO_USER}/.local/share/dwm-pathvoid
	cp -f config.h /home/${SUDO_USER}/.local/share/dwm-pathvoid/config.h
	# Install polybar configs to ~/.local/share/dwm-pathvoid/polybar/
	mkdir -p /home/${SUDO_USER}/.local/share/dwm-pathvoid/polybar
	cp -rf polybar/* /home/${SUDO_USER}/.local/share/dwm-pathvoid/polybar/
	chmod +x /home/${SUDO_USER}/.local/share/dwm-pathvoid/polybar/launch.sh
	chmod +x /home/${SUDO_USER}/.local/share/dwm-pathvoid/polybar/scripts/dwm-tags.sh
	chmod +x /home/${SUDO_USER}/.local/share/dwm-pathvoid/polybar/scripts/dwm-taskbar.sh
	chmod +x /home/${SUDO_USER}/.local/share/dwm-pathvoid/polybar/scripts/wallz/wallz.py
	chmod +x /home/${SUDO_USER}/.local/share/dwm-pathvoid/polybar/scripts/weather/main.py
	chmod +x /home/${SUDO_USER}/.local/share/dwm-pathvoid/polybar/scripts/weather/weather.sh
	chown -R ${SUDO_USER}:${SUDO_USER} /home/${SUDO_USER}/.local/share/dwm-pathvoid
	# Install scripts to PATH
	mkdir -p ${DESTDIR}${PREFIX}/bin
	install -Dm755 scripts/* ${DESTDIR}${PREFIX}/bin/

uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/dwm \
		${DESTDIR}${MANPREFIX}/man1/dwm.1 \
		${DESTDIR}/usr/share/xsessions/dwm.desktop

release: dwm
	mkdir -p release
	cp -f dwm release/
	cp -f dwm.desktop release/
	cp -f .xinitrc release/
	cp -rf polybar release/
	cp -rf scripts release/
	tar -czf release/Omitus-${VERSION}.tar.gz -C release dwm dwm.desktop .xinitrc polybar scripts

.PHONY: all clean install uninstall release
