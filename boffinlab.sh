#!/usr/bin/env bash
# https://www.virtualbox.org/ticket/18410
set -o errexit -o nounset -o pipefail
#set -o xtrace
fix=1
if [ "Darwin" = "$(uname)" ] ; then
	cd $(dirname $0) || exit 1
else
	cd $(dirname $(readlink -f $0)) || exit 1
fi

start() {
	local vm=${1:-boffinlab}
	local sshport=${2:-50022}
	local webport=${3:-58888}
	local rport=${4:-58787}
	local ostype=Debian_64
	local os_iso_url=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.2.0-amd64-netinst.iso
	local os_iso=$(basename $os_iso_url)

	if ! test -e $os_iso; then
		curl --fail --location --create-dirs --output $os_iso-$$ $os_iso_url
		mv $os_iso-$$ $os_iso # this only happens if previous cmds succeeds (because of errexit)
	fi

	local base_dir=$(pwd)/vms
	local aux_base_path=$(pwd)/$vm/$vm-unattended-install-

	VBoxManage unregistervm $vm --delete > /dev/null || true

	rm -fr   $base_dir/$vm
	mkdir -p $base_dir/$vm

	rm -fr   $(dirname $aux_base_path)
	mkdir -p $(dirname $aux_base_path)

	VBoxManage createvm \
			   --name       $vm       \
			   --basefolder $base_dir \
			   --ostype     $ostype   \
			   --register
			   
	VBoxManage modifyvm $vm \
			   --memory 1024 \
			   --vram   16

	VBoxManage storagectl $vm \
			   --name        SAS \
			   --add         sas \
			   --portcount   1   \
			   --bootable    on

	VBoxManage createmedium disk \
			   --filename $base_dir/$vm/$vm.vdi \
			   --size     16384                 \
			   --format   VDI

	# SAS-0-0
	VBoxManage storageattach $vm \
			   --medium     $base_dir/$vm/$vm.vdi \
			   --storagectl SAS                   \
			   --port       0                     \
			   --device     0                     \
			   --type       hdd

	VBoxManage storagectl $vm \
			   --name        SATA \
			   --add         sata \
			   --portcount   1    \
			   --bootable    on

	# SATA-0-0
	VBoxManage storageattach $vm \
			   --medium     emptydrive \
			   --storagectl SATA       \
			   --port       0          \
			   --device     0          \
			   --type       dvddrive   \
			   --mtype      readonly

	VBoxManage modifyvm $vm \
			   --natpf1 "ssh,tcp,,$sshport,,22"
	VBoxManage modifyvm $vm \
			   --natpf1 "web,tcp,,$webport,,8888"
	VBoxManage modifyvm $vm \
			   --natpf1 "rserver,tcp,,$rport,,8787"

	# plug Makefile into the postinstall script
	awk '/H4sIAKG8LWAAA1NW8CvNyeECAD6w57cHAAAA/{system("gzip -c Makefile | base64");next}1' debian_postinstall.sh > debian_postinstall_boffinlab.sh

	VBoxManage unattended install $vm \
			   --auxiliary-base-path $aux_base_path \
			   --iso                 $os_iso \
			   --time-zone=Asia/Tokyo \
			   --post-install-template=debian_postinstall_boffinlab.sh \
			   --install-additions \
			   --user=boffin --password=sauna

	if test ${fix:-0} -ne 0; then # fix isolinux-txt.cfg (isolinux/txt.cfg)
		local fixpath=$(mktemp)
		cat <<EOF > $fixpath
0a1
> default install
1a3
>   menu default
EOF
		echo "fixing ${aux_base_path}isolinux-txt.cfg"
		cp ${aux_base_path}isolinux-txt.cfg ${aux_base_path}isolinux-txt.cfg.orig

		patch ${aux_base_path}isolinux-txt.cfg < $fixpath

		diff ${aux_base_path}isolinux-txt.cfg.orig ${aux_base_path}isolinux-txt.cfg || true
		unlink $fixpath || true
	fi

	# https://www.debian.org/releases/buster/amd64/ch05s03.en.html#installer-args
	sed -i.bak 's/priority=critical/DEBIAN_FRONTEND=noninteractive priority=critical/' ${aux_base_path}isolinux-txt.cfg
	diff -u ${aux_base_path}isolinux-txt.cfg.orig ${aux_base_path}isolinux-txt.cfg || true

	VBoxManage startvm $vm --type headless

	echo "Waiting installation to finish (this will take time)"

	while [ /bin/true ] ; do
		timeout 1m curl -s http://localhost:${webport} > /dev/null 2>&1 && break
		sleep 60
	done

	echo "Installation is done"
	echo "Login using:"
	echo "ssh -o PubkeyAuthentication=no -l root -p $sshport localhost"
	echo "Jupyter URL is http://localhost:${webport}"
	echo "R Server URL is http://localhost:${rport}"
	echo "Password is 'sauna'"
}

start $1 $2 $3 $4
