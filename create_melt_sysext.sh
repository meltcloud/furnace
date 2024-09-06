#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# The github release uses different arch identifiers (not the same as in the other scripts here),
# we map them here and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "x86_64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "aarch64" ]; then
  ARCH="arm64"
fi

rm -rf melt-agent

# install kubernetes binaries.
curl --fail --silent --show-error --location \
  --output melt-agent "https://dl.meltcloud.io/melt-agent/${VERSION}/melt-agent-linux-${ARCH}" 

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/bin
mv melt-agent "${SYSEXTNAME}"/usr/bin/

chmod +x "${SYSEXTNAME}"/usr/bin/melt-agent

# setup melt-agent service.
mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/melt-agent.service" <<-'EOF'
[Unit]
Description=The MELT Agent
Documentation=https://docs.meltcloud.io/agent/
Wants=network-online.target
After=network-online.target

[Service]
CapabilityBoundingSet=CAP_KILL
ExecStart=/usr/bin/melt-agent --conf /etc/melt-agent.yml
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${SYSEXTNAME}/usr/local/share/"
echo "${VERSION}" > "${SYSEXTNAME}/usr/local/share/melt-agent-version"

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d"
{ echo "[Unit]"; echo "Upholds=melt-agent.service"; } > "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d/10-melt-agent-service.conf"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
