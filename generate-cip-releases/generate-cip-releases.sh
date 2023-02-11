#!/bin/bash

TBBUILDDIR="$PWD"

if [ ! -d "$TBBUILDDIR"/aosc-mkrawimg ]; then
	echo "Fetching aosc-mkrawimg ..."
	git clone -b cip/boston https://github.com/AOSC-CIP-Pilot/aosc-mkrawimg
fi

if [[ "$MSA" != "1" ]]; then
	MIPSR6ARCH=mips64r6el
	SUBREPO=rolling
else
	MIPSR6ARCH=mips64r6el+msa
	SUBREPO=rolling+msa
fi

for i in "$@"; do
	echo "Generating system release: $i ..."
	mkdir -pv os-mips64r6el/$i
	rm -rf $i
	aoscbootstrap $SUBREPO $i http://127.0.0.1:8080/debs/ \
		--config /usr/share/aoscbootstrap/config/aosc-mainline.toml \
		-x --arch mips64r6el \
		-s /usr/share/aoscbootstrap/scripts/reset-repo-cip.sh \
		--include-files /usr/share/aoscbootstrap/recipes/$i.lst \
		--export-tar os-mips64r6el/$i/aosc-os_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}.tar.xz
	rm -rf $i

	if [[ "$i" = "base" || \
	      "$i" = "desktop" || \
	      "$i" = "server" ]]; then
		echo "Generating Qemu release: $i ..."
		mkdir -pv os-mips64r6el/$i/rawimg

		cd "$TBBUILDDIR"/aosc-mkrawimg
		env TARBALL="$TBBUILDDIR"/os-mips64r6el/$i/aosc-os_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}.tar.xz \
			DEVICE_NAME=boston \
			SOLUTION=boston \
			IMAGE_NAME="boston_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}" \
			./raw-image-builder

		cd out

		for kern in vmlinux-*-aosc-main; do
			cat > start-qemu-boston.sh << EOF
qemu-system-mips64el \\
	-M boston \\
	-m 2G \\
	-kernel $kern \\
	-append "console=ttyS0,115200 root=/dev/sda1 rw loglevel=4" \\
	-drive file=boston_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}.img,format=raw \\
	-serial mon:stdio -nographic \\
	-monitor telnet:127.0.0.1:55555,server,nowait \\
	-device virtio-net-pci,netdev=net0r6,bus=pci.2 \\
	-netdev user,id=net0r6,net=10.0.2.0/24,host=10.0.2.1,restrict=false
EOF

			cat > start-qemu-virt.sh << EOF
qemu-system-mips64el \\
	-M virt \\
	-m 2G \\
	-kernel $kern \\
	-append "console=ttyS0,115200 root=/dev/vda1 rw loglevel=4" \\
	-drive file=boston_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}.img,format=raw,id=hd0 \\
	-device virtio-blk-device,drive=hd0 \\
	-serial mon:stdio -nographic \\
	-monitor telnet:127.0.0.1:55555,server,nowait \\
	-device virtio-net-pci,netdev=net0r6 \\
	-netdev user,id=net0r6,net=10.0.2.0/24,host=10.0.2.1,restrict=false
EOF
		done

		chmod -v +x start-qemu-*.sh

		tar cvfJ \
			"$TBBUILDDIR"/os-mips64r6el/${i}/rawimg/boston_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}.tar.xz \
			boston_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}.img \
			vmlinux* \
			start-qemu*.sh

		cd "$TBBUILDDIR"/os-mips64r6el/${i}/rawimg
		sha256sum boston_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}.tar.xz \
			> boston_${i}_$(date +%Y%m%d)_${MIPSR6ARCH}.tar.xz.sha256sum

		cd "$TBBUILDDIR"
	fi
done
