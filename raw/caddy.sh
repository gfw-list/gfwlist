#! /bin/bash
# [CTCGFW]Shell-Scripts
# Use it under GPLv3.
# --------------------------------------------------------
# caddy Installer

# Color definition
DEFAULT_COLOR="\033[0m"
BLUE_COLOR="\033[36m"
GREEN_COLOR="\033[32m"
GREEN_BACK="\033[42;37m"
RED_COLOR="\033[31m"
RED_BACK="\033[41;37m"
YELLOW_COLOR="\033[33m"
YELLOW_BACK="\033[43;37m"

# File definition
CADDY_DIR="/usr/bin"
CADDY_BIN="caddy"
CADDY_CONF="Caddyfile"
SERVICE_FILE="/etc/systemd/system/caddy.service"

function __error_msg() {
	echo -e "${RED_COLOR}[ERROR]${DEFAULT_COLOR} $1"
}

function __info_msg() {
	echo -e "${BLUE_COLOR}[INFO]${DEFAULT_COLOR} $1"
}

function __success_msg() {
	echo -e "${GREEN_COLOR}[SUCCESS]${DEFAULT_COLOR} $1"
}

function __warning_msg() {
	echo -e "${YELLOW_COLOR}[WARNING]${DEFAULT_COLOR} $1"
}

function base_check() {
	[ "${EUID}" -ne "0" ] && { __error_msg "You must run me with ROOT access."; exit 1; }

	[ "$(uname)" != "Linux" ] && { __error_msg "Your OS $(uname) is NOT SUPPORTED."; exit 1; }
	if [[ "aarch64 armv6l i686 x86_64" =~ (^|[[:space:]])"$(uname -m)"($|[[:space:]]) ]]; then
		SYSTEM_ARCH="$(uname -m)"
		SYSTEM_ARCH="${SYSTEM_ARCH/x86_64/amd64}"
	else
		__error_msg "Your architecture $(uname -m) is NOT SUPPORTED."
		exit 1
	fi

	[ -e "/etc/redhat-release" ] && SYSTEM_OS="RHEL"
	grep -q "Debian" "/etc/issue" && SYSTEM_OS="DEBIAN"
	grep -q "Ubuntu" "/etc/issue" && SYSTEM_OS="UBUNTU"
	[ -z "${SYSTEM_OS}" ] && { __error_msg "Your OS is not supported."; exit 1; }

	command -v "systemctl" > "/dev/null" || { __error_msg "Systemd is NOT FOUND."; exit 1; }
}

function check_status(){
	if [ -f "${CADDY_DIR}/${CADDY_BIN}" ]; then
		INSTALL_STATUS="${GREEN_COLOR}Installed${DEFAULT_COLOR}"
		CADDY_PID="$(pidof "${CADDY_BIN}")"
		if [ -z "${CADDY_PID}" ]; then
			RUNNING_STATUS="${RED_COLOR}Not Running${DEFAULT_COLOR}"
			CADDY_INFO="${RED_COLOR}Not Running${DEFAULT_COLOR}"
			CADDY_VERSION="$(caddy version)"

		else
			RUNNING_STATUS="${GREEN_COLOR}Running${DEFAULT_COLOR} | ${GREEN_COLOR}${CADDY_PID}${DEFAULT_COLOR}"
			NAIVE_DOMAIN="$(grep "443" "/etc/caddy/${CADDY_CONF}" | awk -F ' ' '{print $2}')"
			NAIVE_USER="$(grep "basic_auth" "/etc/caddy/${CADDY_CONF}" | awk -F ' ' '{print $2}')"
			NAIVE_PASS="$(grep "basic_auth" "/etc/caddy/${CADDY_CONF}" | awk -F ' ' '{print $3}')"
			TROJAN_PASS="$(grep "user" "/etc/caddy/${CADDY_CONF}" | awk -F ' ' '{print $2,$3}' )"
			AUTH_TRIGGER="$(grep "probe_resistance" "/etc/caddy/${CADDY_CONF}" | awk -F ' ' '{print $2}')"
			CADDY_VERSION="$(caddy version)"

			CADDY_INFO="
  ${GREEN_BACK}Domain: ${NAIVE_DOMAIN}:443${DEFAULT_COLOR}
  ${GREEN_BACK}Trojan Password: ${TROJAN_PASS}${DEFAULT_COLOR}
  ${GREEN_BACK}Naiveproxy: ${NAIVE_USER}:${NAIVE_PASS}${DEFAULT_COLOR}
  ${GREEN_BACK}Probe_resistance: ${AUTH_TRIGGER}${DEFAULT_COLOR}"
		fi
	else
		INSTALL_STATUS="${RED_COLOR}Not Installed${DEFAULT_COLOR}"
		RUNNING_STATUS="${RED_COLOR}Not Installed${DEFAULT_COLOR}"
		CADDY_INFO="${YELLOW_COLOR}Empty${DEFAULT_COLOR}"
		CADDY_VERSION="${YELLOW_COLOR}Not Found${DEFAULT_COLOR}"
	fi
}

function print_menu(){
	echo -e "caddy Install Status: ${INSTALL_STATUS}
caddy Running Status: ${RUNNING_STATUS}
----------------------------------------
${BLUE_COLOR}Caddy Version: ${CADDY_VERSION}${DEFAULT_COLOR}
----------------------------------------
	1. Install caddy
	2. Remove caddy

	3. Start/Stop caddy
	4. Restart caddy

	5. Exit
----------------------------------------
       Configuration: ${CADDY_INFO}
----------------------------------------"
	read -e -r -p "Action [1-5]: " DO_ACTION
	case "${DO_ACTION}" in
	"1")
		install_caddy
		;;
	"2")
		remove_caddy
		;;
	"3")
		start_stop_caddy
		;;
	"4")
		restart_caddy
		;;
	"5")
		exit 1
		;;	
	*)
		__error_msg "Number ${DO_ACTION} is NOT DEFINED."
		exit 1
		;;
	esac
}

function install_caddy() {
	[ -f "${CADDY_DIR}/${CADDY_BIN}" ] && {
		__info_msg "caddy is installed already."
		read -e -r -p 'Do you want to reinstall? [y/N]: ' REINSTALL_caddy
		case "${REINSTALL_caddy}" in
		[yY][eE][sS]|[yY])
			__info_msg "Removing existing caddy ..."
			remove_caddy
			;;
		*)
			__error_msg "The action is canceled by user."
			exit 1
			;;
		esac
	}

	__info_msg "Checking port ..."
	for i in {80,443}
	do
		[ -n "$(lsof -i:"$i")" ] && {
			__error_msg "Port $i is already in use, see the following info:"
			lsof -i:"$i"
			read -e -r -p "Try to force kill the progress? [Y/n]: " PORT_CONFLICT_RESOLVE
			case "${PORT_CONFLICT_RESOLVE}" in
			[nN][oO]|[nN])
				__error_msg "The action is canceled by user."
				exit 1
				;;
			*)
				__info_msg "Trying to kill the progress ..."
				if lsof -i:"$i" | awk '{print $1}' | grep -v "COMMAND" | grep -q "apache"; then
					systemctl stop apache
					systemctl disable apache
					systemctl stop apache2
					systemctl disable apache2
				fi
				if lsof -i:"$i" | awk '{print $1}' | grep -v "COMMAND" | grep -q "caddy"; then
					systemctl stop caddy
					systemctl disable caddy
				fi
				if lsof -i:"$i" | awk '{print $1}' | grep -v "COMMAND" | grep -q "nginx"; then
					systemctl stop nginx
					systemctl disable nginx
				fi
				lsof -i:"$i" | awk '{print $2}' | grep -v "PID" | xargs kill -9
				__info_msg "Waiting for 5s ..."
				sleep 5s
				if lsof -i:"$i" > "/dev/null"; then
					__error_msg "Failed to kill the progress, please check it by yourself."
					exit 1
				else
					__success_msg "Progress now is killed."
				fi
				;;
			esac
		}
	done

	__info_msg "Please provide the following info: "
	read -e -r -p "Domain (e.g. example.com): " CONF_DOMAIN
	[ -z "${CONF_DOMAIN}" ] && { __error_msg "Domain cannot be empty."; exit 1; }
	read -e -r -p "E-mail (e.g. naive@example.com): " CONF_EMAIL
	[ -z "${CONF_EMAIL}" ] && { __error_msg "E-mail cannot be empty."; exit 1; }
	read -e -r -p "Trojan Password (e.g. pass): " CONF_TROJAN
	[ -z "${CONF_TROJAN}" ] && { __error_msg "Trojan Password cannot be empty."; exit 1; }
	read -e -r -p "Naive Username (e.g. user): " CONF_USER
	[ -z "${CONF_USER}" ] && { __error_msg "Naive Username cannot be empty."; exit 1; }
	read -e -r -p "Naive Password (e.g. pass): " CONF_PASS
	[ -z "${CONF_PASS}" ] && { __error_msg "Naive Password cannot be empty."; exit 1; }
    read -e -r -p "Probe_resistance (e.g. secret-link-kWWL9Q.com): " PROBE_RESISTANCE
	[ -z "${PROBE_RESISTANCE}" ] && { __warning_msg "Probe_resistance can be empty if you are not going to use SwitchyOmega.";}

	__info_msg "Installing dependencies ..."
	if [ "${SYSTEM_OS}" == "RHEL" ]; then
		yum update -y
		yum install -y epel-release
		yum install -y ca-certificates curl firewalld git lsof libcap
		firewall-cmd --permanent --zone=public --add-port=22/tcp
		systemctl start firewalld
		firewall-cmd --reload
	else
		apt update -y
		apt install -y ca-certificates curl git lsof libcap2-bin
	    <<-EOF
			y
		EOF
		groupadd --system caddy
        useradd --system \
        --gid caddy \
        --create-home \
        --home-dir /var/lib/caddy \
        --shell /usr/sbin/nologin \
        --comment "Caddy web server" \
        caddy
	fi

	INSTALL_TEMP_DIR="$(mktemp -p "/tmp" -d "naive.XXXXXX")"
	pushd "${INSTALL_TEMP_DIR}" || { __error_msg "Failed to enter tmp directory."; exit 1; }

	__info_msg "Checking go version ..."
	go version 2>"/dev/null" | grep -q "go1\.[0-9]+\.[0-9]+" || {
		__info_msg "Downloading Go latest version ..."

		GO_LATEST_VER=`curl -s https://go.dev/VERSION?m=text`
		curl --retry "5" --retry-delay "3" --location "https://go.dev/dl/${GO_LATEST_VER}.linux-${SYSTEM_ARCH}.tar.gz" --output "golang.${GO_LATEST_VER}.tar.gz"
		tar -zxf "golang.${GO_LATEST_VER}.tar.gz"
		rm -f "golang.${GO_LATEST_VER}.tar.gz"
		[ ! -f "./go/bin/go" ] && { __error_msg "Failed to download go binary."; popd; rm -rf "${INSTALL_TEMP_DIR}"; exit 1; }
		export PATH="$PWD/go/bin:$PATH"
		export GOROOT="$PWD/go"
		export GOTOOLDIR="$PWD/go/pkg/tool/linux_amd64"
	}

	export GOBIN="$PWD/gopath/bin"
	export GOCACHE="$PWD/go-cache"
	export GOPATH="$PWD/gopath"
	export GOMODCACHE="$GOPATH/pkg/mod"

	__info_msg "Fetching Caddy builder ..."
	go install "github.com/caddyserver/xcaddy/cmd/xcaddy@latest"
	__info_msg "Building caddy (this may take a few minutes to be completed) ..."
	"${GOBIN}/xcaddy" build master --with "github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive" --with "github.com/caddyserver/transform-encoder" --with "github.com/imgk/caddy-trojan" --with "github.com/caddy-dns/cloudflare" 

	if [ -n "$(./caddy version)" ]; then
		__success_msg "caddy version: $(./caddy version)"
	else
		__error_msg "Failed to build caddy."
		popd
		rm -rf "${INSTALL_TEMP_DIR}"
		exit 1
	fi

	mkdir -p "${CADDY_DIR}"
	mkdir -p "/etc/${CADDY_BIN}"
	mv "./caddy" "${CADDY_DIR}/${CADDY_BIN}"
	setcap cap_net_bind_service=+ep "${CADDY_DIR}/${CADDY_BIN}"

	popd
	rm -rf "${INSTALL_TEMP_DIR}"

	__info_msg "Setting up configure files ..."
	pushd "/etc/caddy"

	mkdir -p "wwwhtml"
        wget -P "/usr/share/caddy" "https://raw.githubusercontent.com/caddyserver/dist/master/welcome/index.html"
	echo -e "
{
        servers {
                listener_wrappers {
                        trojan
                }
                protocol {
                        allow_h2c
                        experimental_http3
                }
        }
        trojan {
		caddy
		no_proxy
		users ${CONF_TROJAN}
	}
}
:443, ${CONF_DOMAIN} {
        tls ${CONF_EMAIL} {
                protocols tls1.2 tls1.3
        }
        route {
                trojan {
                       	connect_method
			websocket                
		}
                forward_proxy {
                        basic_auth ${CONF_USER} ${CONF_PASS}
                        hide_ip
                        hide_via
                        probe_resistance ${PROBE_RESISTANCE}
                }
                file_server {
                        root  /usr/share/caddy
                }
        }
}" > "${CADDY_CONF}"

	cat <<-EOF > "${SERVICE_FILE}"
[Unit]
Description=caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target 

[Service]
User=caddy
Group=caddy

ExecStart=${CADDY_DIR}/${CADDY_BIN} run --environ --config /etc/caddy/${CADDY_CONF}
ExecReload=${CADDY_DIR}/${CADDY_BIN} reload --config /etc/caddy/${CADDY_CONF}
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full

AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
	EOF
	systemctl enable "${CADDY_BIN}"

	popd


	__info_msg "Starting caddy ..."
	systemctl start "${CADDY_BIN}"
	__info_msg "Waiting for 5s ..."
	sleep 5s
	pidof "${CADDY_BIN}" > "/dev/null" || __error_msg "Failed to start caddy, please check your configure."

echo -e "\n\n"
	__success_msg "Installation is finished, see connection info below:"
	echo -e "
	${BLUE_COLOR}----------------------------------------
   Caddy Version:$(caddy version)
	----------------------------------------
	Trojan:${CONF_TROJAN}
	----------------------------------------
	Naive:${CONF_USER}@${CONF_PASS}
	----------------------------------------
	Domain:${CONF_DOMAIN}:443
	----------------------------------------
	Probe_resistance:${PROBE_RESISTANCE}
	----------------------------------------${DEFAULT_COLOR}"
}
function remove_caddy() {
	[ ! -f "${CADDY_DIR}/${CADDY_BIN}" ] && { __error_msg "caddy is never installed."; exit 1; }

	__warning_msg "You are about to remove caddy. Is that correct?"
		read -e -r -p 'Are you sure? [y/N]: ' COMFIRM_REMOVE
		case "${COMFIRM_REMOVE}" in
		[yY][eE][sS]|[yY])
			__info_msg "Stopping caddy ..."
			systemctl stop "${CADDY_BIN}"

			__info_msg "Removing caddy files ..."
			systemctl disable "${CADDY_BIN}"
			rm -f "${SERVICE_FILE}"
			rm -f "${CADDY_DIR}/${CADDY_BIN}"
			rm -f "/etc/caddy/${CADDY_CONF}"

     		__success_msg "caddy is removed."
			;;
		*)
			__error_msg "The action is canceled by user."
			exit 1
			;;
		esac
}

function start_stop_caddy() {
	[ ! -f "${CADDY_DIR}/${CADDY_BIN}" ] && { __error_msg "caddy is never installed."; exit 1; }

	if pidof "${CADDY_BIN}" > "/dev/null"; then
		__info_msg "Stopping caddy ..."
		systemctl stop "${CADDY_BIN}"
		__info_msg "Waiting for 5s ..."
		sleep 5s
		if pidof "${CADDY_BIN}" > "/dev/null"; then
			__error_msg "Failed to stop caddy."
		else
			__success_msg "caddy is stopped."
		fi
	else
		__info_msg "Starting caddy ..."
		systemctl start "${CADDY_BIN}"
		__info_msg "Waiting for 5s ..."
		sleep 5s
		if pidof "${CADDY_BIN}" > "/dev/null"; then
			__success_msg "caddy is started."
		else
			__error_msg "Failed to start caddy."
		fi
	fi
}

function restart_caddy() {
	[ ! -f "${CADDY_DIR}/${CADDY_BIN}" ] && { __error_msg "caddy is never installed."; exit 1; }

	__info_msg "Restarting caddy ..."
	systemctl restart "${CADDY_BIN}"
	__info_msg "Waiting for 5s ..."
	sleep 5s
	if pidof "${CADDY_BIN}" > "/dev/null"; then
		__success_msg "caddy is restarted."
	else
		__error_msg "Failed to restart caddy."
	fi
}

function main() {
	base_check
	check_status
	print_menu
}

main
