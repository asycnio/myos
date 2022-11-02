
variable "accelerator" {
  type    = string
  default = "kvm"
}

variable "alpine_arch" {
  type    = string
  default = "x86_64"
}

variable "alpine_release" {
  type    = string
  default = "3.16.0"
}

variable "alpine_version" {
  type    = string
  default = "3.16"
}

variable "ansible_extra_vars" {
  type    = string
  default = "target=default"
}

variable "ansible_user" {
  type    = string
  default = "root"
}

variable "ansible_verbose" {
  type    = string
  default = "-v"
}

variable "boot_wait" {
  type    = string
  default = "8s"
}

variable "hostname" {
  type    = string
  default = "alpine"
}

variable "iso_name" {
  type    = string
  default = "alpine-3.16.0-x86_64"
}

variable "iso_size" {
  type    = string
  default = "1024"
}

variable "nameserver" {
  type    = string
  default = "1.1.1.1"
}

variable "output" {
  type    = string
  default = "build/iso"
}

variable "password" {
  type    = string
  default = "alpine"
}

variable "pause_before" {
  type    = string
  default = "24s"
}

variable "qemuargs" {
  type    = string
  default = ""
}

variable "ssh_port_max" {
  type    = string
  default = "2222"
}

variable "ssh_port_min" {
  type    = string
  default = "2222"
}

variable "ssh_timeout" {
  type    = string
  default = "42s"
}

variable "template" {
  type    = string
  default = "alpine"
}

variable "username" {
  type    = string
  default = "root"
}

variable "vnc_bind_address" {
  type    = string
  default = "127.0.0.1"
}

variable "vnc_port_max" {
  type    = string
  default = "5900"
}

variable "vnc_port_min" {
  type    = string
  default = "5900"
}

source "qemu" "alpine" {
  accelerator              = "${var.accelerator}"
  boot_command             = ["${var.username}<enter>", "passwd<enter>${var.password}<enter>${var.password}<enter>", "ifconfig eth0 up && udhcpc -i eth0<enter>", "apk add --repository http://dl-cdn.alpinelinux.org/alpine/v${var.alpine_version}/main dropbear dropbear-openrc openssh-sftp-server<enter>", "rc-update add dropbear<enter>", "echo -e 'auto eth0\\niface eth0 inet dhcp' > /etc/network/interfaces<enter>", "mkdir -p /etc/dropbear<enter>", "dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key<enter>", "rc-service dropbear start<enter>", "<wait>"]
  boot_wait                = "${var.boot_wait}"
  disk_interface           = "virtio"
  disk_size                = "${var.iso_size}"
  format                   = "raw"
  headless                 = true
  host_port_max            = "${var.ssh_port_max}"
  host_port_min            = "${var.ssh_port_min}"
  iso_checksum             = "file:http://dl-cdn.alpinelinux.org/alpine/v${var.alpine_version}/releases/${var.alpine_arch}/alpine-virt-${var.alpine_release}-${var.alpine_arch}.iso.sha256"
  iso_url                  = "http://dl-cdn.alpinelinux.org/alpine/v${var.alpine_version}/releases/${var.alpine_arch}/alpine-virt-${var.alpine_release}-${var.alpine_arch}.iso"
  net_device               = "virtio-net"
  output_directory         = "${var.output}"
  qemuargs                 = [["-device", "virtio-rng-pci,rng=rng0,bus=pci.0,addr=0x7"], ["-object", "rng-random,filename=/dev/urandom,id=rng0"]]
  // qemuargs                 = ["${var.qemuargs}"]
  shutdown_command         = "/sbin/poweroff"
  ssh_file_transfer_method = "sftp"
  ssh_password             = "${var.password}"
  ssh_port                 = 22
  ssh_timeout              = "${var.ssh_timeout}"
  ssh_username             = "${var.username}"
  vm_name                  = "${var.iso_name}.iso"
  vnc_bind_address         = "${var.vnc_bind_address}"
  vnc_port_max             = "${var.vnc_port_max}"
  vnc_port_min             = "${var.vnc_port_min}"
}

build {
  sources = ["source.qemu.alpine"]

  provisioner "shell" {
    environment_vars = ["ALPINE_VERSION=${var.alpine_version}", "HOSTNAME=${var.hostname}", "NAMESERVER=${var.nameserver}"]
    script           = "packer/alpine/setup.sh"
  }

  provisioner "shell" {
    expect_disconnect = true
    inline            = ["/usr/bin/eject -s", "/sbin/reboot"]
  }

  provisioner "ansible" {
    ansible_env_vars       = [ "ANSIBLE_USERNAME=${var.ansible_user}" ]
    // https://github.com/hashicorp/packer-plugin-ansible/issues/69
    ansible_ssh_extra_args = ["-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"]
    extra_arguments        = ["--extra-vars", "${var.ansible_extra_vars}", "${var.ansible_verbose}"]
    inventory_directory    = "ansible/inventories"
    pause_before           = "${var.pause_before}"
    playbook_file          = "ansible/playbook.yml"
    sftp_command           = "/usr/lib/ssh/sftp-server -e"
    use_proxy              = "true"
    use_sftp               = "true"
    user                   = "${var.ansible_user}"
  }

}