#!/usr/local/bin/bash

unset VCS_BACKUPS_CONFIG
unset VCS_BACKUPS_WORKDIR

while [[ $# -gt 0 ]]; do
 if [[ $# -lt 2 ]]; then echo 'Wrong flags!' >&2; exit 1; fi
 case "$1" in
  '--config')
   if [[ -v VCS_BACKUPS_CONFIG ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   VCS_BACKUPS_CONFIG="$2"; shift 2;;
  '--workdir')
   if [[ -v VCS_BACKUPS_WORKDIR ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   VCS_BACKUPS_WORKDIR="$2"; shift 2;;
  *) echo "\"$1\" is not supported!" >&2; exit 1;;
 esac
done

#

if [[ ! -v VCS_BACKUPS_WORKDIR ]]; then
 VCS_BACKUPS_WORKDIR="$(pwd)"
 if [[ $? != 0 ]]; then echo 'Get workdir error!' >&2; exit 1; fi
fi

if [[ -z "${VCS_BACKUPS_WORKDIR}" ]]; then
 echo 'No workdir!' >&2; exit 1
elif [[ -L "${VCS_BACKUPS_WORKDIR}" ]]; then
 echo "\"${VCS_BACKUPS_WORKDIR}\" is a symlink!" >&2; exit 1
fi

VCS_BACKUPS_WORKDIR="$(realpath -- "${VCS_BACKUPS_WORKDIR}")"
if [[ $? != 0 ]]; then
 echo 'Realpath workdir error!' >&2; exit 1
elif [[ ! -e "${VCS_BACKUPS_WORKDIR}" ]]; then
 echo "\"${VCS_BACKUPS_WORKDIR}\" does not exist!" >&2; exit 1
elif [[ ! -d "${VCS_BACKUPS_WORKDIR}" ]]; then
 echo "\"${VCS_BACKUPS_WORKDIR}\" is not a dir!" >&2; exit 1
fi

#

if [[ ! -v VCS_BACKUPS_CONFIG ]]; then
 VCS_BACKUPS_CONFIG="${VCS_BACKUPS_WORKDIR}/reps.yml"
fi

if [[ -z "${VCS_BACKUPS_CONFIG}" ]]; then
 echo 'No config!' >&2; exit 1
elif [[ -L "${VCS_BACKUPS_CONFIG}" ]]; then
 echo "\"${VCS_BACKUPS_CONFIG}\" is a symlink!" >&2; exit 1
fi
VCS_BACKUPS_CONFIG="$(realpath -- "${VCS_BACKUPS_CONFIG}")"
if [[ $? != 0 ]]; then
 echo 'Realpath config error!' >&2; exit 1
elif [[ ! -e "${VCS_BACKUPS_CONFIG}" ]]; then
 echo "\"${VCS_BACKUPS_CONFIG}\" does not exist!" >&2; exit 1
elif [[ ! -f "${VCS_BACKUPS_CONFIG}" ]]; then
 echo "\"${VCS_BACKUPS_CONFIG}\" is not a file!" >&2; exit 1
elif [[ ! -s "${VCS_BACKUPS_CONFIG}" ]]; then
 echo "\"${VCS_BACKUPS_CONFIG}\" is empty!" >&2; exit 1
fi

#

echo 'Not implemented!' >&2; exit 1 # todo
