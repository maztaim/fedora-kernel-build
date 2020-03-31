#!/usr/bin/env bash
: '
Usage: $0 <kernel version you want to build>


Patches should be in the current working directory where you call this script. and
have a file format of "descriptive.patch".  Each patch should be a diff with a
header similar to the following example."

---
From: Some Person <some@email.com>
Subject: [PATCH] The Patch Description

The diff goes here.
---
'
[[ -z $1 ]] && { echo "No kernel version given."; exit 9; } || version=$1

ls *.patch > /dev/null 2>&1 && patches=$(ls *.patch) || { echo "No patches to add."; exit 1; }

# Make sure we have all the packages we need to build a kernel.
sudo dnf install fedpkg fedora-packager rpmdevtools ncurses-devel pesign || { echo "Unable to install all packages."; exit 2; }

# Set up the rpmdev tree.
rpmdev-setuptree || { echo "Unable to setup rpmdev tree."; exit 3; }

# Grab a copy of the kernel source.
koji download-build --arch=src kernel-${version}.src.rpm || { echo "Unable to download kernel."; exit 4; }

# Install the kernel into the rpmdev tree.
rpm -Uvh kernel-${version}.src.rpm || { echo "Unable to install kernel source"; exit 5; }

# Setup the kernel.spec to add patches and provide a local version of the rpm package.
(cd ~/rpmbuild/SPECS; sudo dnf builddep kernel.spec)
sed -i "s/# define buildid \.local/%define buildid \.fkp/g" ~/rpmbuild/SPECS/kernel.spec

patchcount=9000
for patch in $patches; do
	# Copy the patches in and add them to the kernel.spec.
	cp $patch ~/rpmbuild/SOURCES || { echo "Unable to copy ${patch}." ; exit 6; }
	sed -i "/^# END OF PATCH DEFINITIONS/i Patch${patchcount}: ${patch}\n" ~/rpmbuild/SPECS/kernel.spec || { echo "Unable to add ${patch} to kernel.spec."; exit 7; }
	((patchcount++))
done

# Build that kernel as quickly as possible.
# \\ TODO: Maybe add an option variable to adjust what you want to actually build?
rpmbuild -bb --without debug --without doc --without perf --without tools --without debuginfo --without kdump --without bootwrapper --without cross_headers --target=x86_64 ~/rpmbuild/SPECS/kernel.spec || { echo "Something went wrong with the build."; exit 8; }

echo
echo "That should do it.  Now you can install the new kernel using the following."
echo ---
echo sudo dnf install ~/rpmbuild/RPMS/x86_64/kernel*
echo sudo grub2-mkconfig -o /etc/grub2-efi.cfg
echo reboot
echo ---
echo Select the new kernel to test. 
