#!/bin/bash -eu

set +H -euo pipefail

if [ "${PCLOUD_DEBUG:=0}" == "1" ]; then
  echo "# Enabling debug output"
  set -x
fi

# Cleanup password file on exit
trap 'rm -f /tmp/pcloud_pass' EXIT

PCLOUD_DRIVE_PATH="/pCloudDrive"

: ${PCLOUD_UID:=$(stat ${PCLOUD_DRIVE_PATH} -c '%u')}
: ${PCLOUD_GID:=$(stat ${PCLOUD_DRIVE_PATH} -c '%g')}

# Create new group using target GID
if ! pcloud_group="$(getent group "$PCLOUD_GID")"; then
  pcloud_group='pcloud'
  groupadd "${pcloud_group}" -g "$PCLOUD_GID"
else
  pcloud_group=${pcloud_group%%:*}
fi

# Create new user using target UID
if ! pcloud_user="$(getent passwd "$PCLOUD_UID")"; then
  pcloud_user='pcloud'
  useradd -m "${pcloud_user}" -u "$PCLOUD_UID" -g "$PCLOUD_GID"
else
  pcloud_user="${pcloud_user%%:*}"
  usermod -g "${pcloud_group}" "${pcloud_user}"
  grep -qv root <( groups "${pcloud_user}" ) || { echo 'ROOT level privileges prohibited!'; exit 1; }
fi

ARGS=(-m ${PCLOUD_DRIVE_PATH})
echo "Base Args: ${ARGS}"

if [ -n "${PCLOUD_SAVE_PASSWORD:=''}" ]; then
  echo "# Adding -s to save password"
  ARGS=(-s ${ARGS[@]})
fi

if [ -n "${PCLOUD_USERNAME:=''}" ]; then
  ARGS=(-u ${PCLOUD_USERNAME} ${ARGS[@]})
fi

# Conditionally pass the password
# from a password file, PCLOUD_PASSWORD env var, or stdin
# https://stackoverflow.com/a/1987599
password_file_stdin=""
if [ -n "${PCLOUD_PASSWORD_FILE:=""}" ]; then
  password_file_stdin="${PCLOUD_PASSWORD_FILE}"
  ARGS=(-p ${ARGS[@]})
elif [ -n "${PCLOUD_PASSWORD:=""}" ]; then
  # Use password from env var via temporary file
  password_file_stdin="/tmp/pcloud_pass"
  echo "${PCLOUD_PASSWORD}" > "${password_file_stdin}"
  chmod 600 "${password_file_stdin}"
  ARGS=(-p ${ARGS[@]})
else
  # Prompt for password if no file/env is provided
  ARGS=(-p ${ARGS[@]})
fi

echo "# Launching pcloud"
# Only switch user if not running as target uid (ie. Docker)
if [ "$PCLOUD_UID" = "$(id -u)" ]; then
  set -x
  if [ -n "${password_file_stdin}" ]; then
    /usr/bin/pcloudcc "${ARGS[@]}" < "${password_file_stdin}"
  else
    /usr/bin/pcloudcc "${ARGS[@]}"
  fi
else
  mkdir -p ${PCLOUD_DRIVE_PATH}
  chown "${pcloud_user}:${pcloud_group}" ${PCLOUD_DRIVE_PATH}
  chown -R "${pcloud_user}:${pcloud_group}" /home/${pcloud_user}
  set -x
  if [ -n "${password_file_stdin}" ]; then
    exec gosu "${pcloud_user}" /usr/bin/pcloudcc "${ARGS[@]}" < "${password_file_stdin}"
  else
    exec gosu "${pcloud_user}" /usr/bin/pcloudcc "${ARGS[@]}"
  fi
fi