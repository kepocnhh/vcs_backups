#!/usr/local/bin/bash

unset VCS_BACKUPS_CONFIG
unset VCS_BACKUPS_REPSDIR
unset VCS_BACKUPS_WORKDIR

while [[ $# -gt 0 ]]; do
 if [[ $# -lt 2 ]]; then echo 'Wrong flags!' >&2; exit 1; fi
 case "$1" in
  '--config')
   if [[ -v VCS_BACKUPS_CONFIG ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   VCS_BACKUPS_CONFIG="$2"; shift 2;;
  '--repsdir')
   if [[ -v VCS_BACKUPS_REPSDIR ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   VCS_BACKUPS_REPSDIR="$2"; shift 2;;
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

if [[ -v VCS_BACKUPS_REPSDIR ]]; then
 if [[ -z "${VCS_BACKUPS_REPSDIR}" ]]; then
  echo 'No repsdir!' >&2; exit 1
 elif [[ -L "${VCS_BACKUPS_REPSDIR}" ]]; then
  echo "\"${VCS_BACKUPS_REPSDIR}\" is a symlink!" >&2; exit 1
 fi
 VCS_BACKUPS_REPSDIR="$(realpath -- "${VCS_BACKUPS_REPSDIR}")"
 if [[ $? != 0 ]]; then
  echo 'Realpath repsdir error!' >&2; exit 1
 elif [[ ! -e "${VCS_BACKUPS_REPSDIR}" ]]; then
  echo "\"${VCS_BACKUPS_REPSDIR}\" does not exist!" >&2; exit 1
 elif [[ ! -d "${VCS_BACKUPS_REPSDIR}" ]]; then
  echo "\"${VCS_BACKUPS_REPSDIR}\" is not a dir!" >&2; exit 1
 fi
else
 VCS_BACKUPS_REPSDIR="${VCS_BACKUPS_WORKDIR}"
fi

# github

GITHUB_API='https://api.github.com'
GITHUB_API_VERSION='2026-03-10'
GITHUB_PER_PAGE=64
GITHUB_DST="$(mktemp)"

GITHUB_OWNERS_COUNT="$(yq -Mer -p=yml -o=yml '.github.owners | length' "${VCS_BACKUPS_CONFIG}")"
if [[ $? != 0 ]]; then
 echo 'Get owners count error!' >&2; exit 1
elif [[ ! "${GITHUB_OWNERS_COUNT}" =~ ^[1-9][0-9]?$ ]]; then
 echo 'Wrong owners count!' >&2; exit 1
fi

mapfile -d '' -t GITHUB_OWNERS < <(yq -Mer -0 -p=yml -o=yml '.github.owners[]' "${VCS_BACKUPS_CONFIG}")
if [[ ${#GITHUB_OWNERS[@]} -eq 0 ]]; then
 echo 'No owners!' >&2; exit 1; fi

VALUE_NUMBER=0
while IFS= read -r -d '' GITHUB_OWNER; do
 if [[ -z "${GITHUB_OWNER}" ]]; then
  echo 'No owner!' >&2; exit 1
 elif [[ ! "${GITHUB_OWNER}" =~ ^(_|[a-z]|[A-Z]|[0-9])+$ ]]; then
  echo 'Wrong owner!' >&2; exit 1
 fi
 #
 GITHUB_OWNER_DIR="${VCS_BACKUPS_REPSDIR}/${GITHUB_OWNER}"
 if [[ -L "${GITHUB_OWNER_DIR}" ]]; then
  echo "\"${GITHUB_OWNER_DIR}\" is a symlink!" >&2; exit 1
 elif [[ -e "${GITHUB_OWNER_DIR}" ]]; then
  if [[ ! -d "${GITHUB_OWNER_DIR}" ]]; then
   echo "\"${GITHUB_OWNER_DIR}\" is not a dir!" >&2; exit 1; fi
 else
  mkdir "${GITHUB_OWNER_DIR}"
  if [[ $? != 0 || ! -d "${GITHUB_OWNER_DIR}" ]]; then
   echo "Make \"${GITHUB_OWNER_DIR}\" dir error!"; exit 1; fi
 fi
 #
 VALUE_NUMBER=$((VALUE_NUMBER+1))
 echo "owner[${VALUE_NUMBER}/${GITHUB_OWNERS_COUNT}]: ${GITHUB_OWNER}"
done < <(printf '%s\0' "${GITHUB_OWNERS[@]}" | LC_ALL=C sort -z)

#

echo 'Not implemented!' >&2; exit 1 # todo
