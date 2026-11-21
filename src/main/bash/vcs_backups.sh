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

VCS_BACKUPS_LOGS="$(mktemp)" || exit 1
STDERR="$(mktemp)" || exit 1

#

printf $'\n''GitHub owners...'$'\n'

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

GITHUB_OWNER_NUMBER=0
while IFS= read -r -d '' GITHUB_OWNER; do
 if [[ -z "${GITHUB_OWNER}" ]]; then
  echo 'No owner!' >&2; exit 1
 elif [[ "${GITHUB_OWNER}" == '.' || "${GITHUB_OWNER}" == '..' || ! "${GITHUB_OWNER}" =~ ^[a-zA-Z0-9\._-]+$ ]]; then
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
 rm "${GITHUB_DST}"
 HTTP_CODE=$(curl -m 8 -w '%{http_code}' \
  --url "${GITHUB_API}/users/${GITHUB_OWNER}/repos?per_page=${GITHUB_PER_PAGE}&sort=pushed" \
  --header 'Accept: application/vnd.github+json' \
  --header "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
  -o "${GITHUB_DST}" 2>/dev/null)
 if [[ $? -ne 0 || "${HTTP_CODE}" != '200' ]]; then
  echo "Request \"${GITHUB_OWNER}\" error!" >&2; continue; fi
 #
 GITHUB_REPS_COUNT="$(yq -Mer -p=json -o=json 'length' "${GITHUB_DST}")"
 if [[ $? != 0 ]]; then
  echo 'Get reps count error!' >&2; exit 1
 elif [[ ! "${GITHUB_REPS_COUNT}" =~ ^[1-9][0-9]?$ ]]; then
  echo 'Wrong reps count!' >&2; exit 1
 fi
 mapfile -d '' -t GITHUB_REPS < <(yq -Mer -0 -p=json -o=json '.[].name' "${GITHUB_DST}")
 if [[ ${#GITHUB_REPS[@]} -eq 0 ]]; then
  echo 'No reps!' >&2; exit 1; fi
 GITHUB_OWNER_NUMBER=$((GITHUB_OWNER_NUMBER+1))
 GITHUB_REP_NUMBER=0
 while IFS= read -r -d '' GITHUB_REP; do
  GITHUB_REP_NUMBER=$((GITHUB_REP_NUMBER+1))
  printf "%02d/%02d %s %02d/%02d %s"$'\n' "${GITHUB_OWNER_NUMBER}" "${GITHUB_OWNERS_COUNT}" "${GITHUB_OWNER}" "${GITHUB_REP_NUMBER}" "${GITHUB_REPS_COUNT}" "${GITHUB_REP}"
  :> "${STDERR}"
  "${VCS_BACKUPS_WORKDIR}/github_backups.sh" --repsdir "${VCS_BACKUPS_REPSDIR}" --owner "${GITHUB_OWNER}" --rep "${GITHUB_REP}" 2> "${STDERR}"
  if [[ $? != 0 ]]; then
   printf '%s' "Backup ${GITHUB_OWNER}/${GITHUB_REP} error!" | tee -a "${VCS_BACKUPS_LOGS}" >&2
   cat -- "${STDERR}" >> "${VCS_BACKUPS_LOGS}"
  fi
 done < <(printf '%s\0' "${GITHUB_REPS[@]}" | LC_ALL=C sort -z)
done < <(printf '%s\0' "${GITHUB_OWNERS[@]}" | LC_ALL=C sort -z)

#

printf $'\n''GitHub repositories...'$'\n'

GITHUB_OWNERS_COUNT="$(yq -Mer -p=yml -o=yml '.github.reps | length' "${VCS_BACKUPS_CONFIG}")"
if [[ $? != 0 ]]; then
 echo 'Get owners count error!' >&2; exit 1
elif [[ ! "${GITHUB_OWNERS_COUNT}" =~ ^[1-9][0-9]?$ ]]; then
 echo 'Wrong owners count!' >&2; exit 1
fi

mapfile -d '' -t GITHUB_OWNERS < <(yq -Mer -0 -p=yml -o=yml '.github.reps | keys | .[]' "${VCS_BACKUPS_CONFIG}")
if [[ ${#GITHUB_OWNERS[@]} -eq 0 ]]; then
 echo 'No owners!' >&2; exit 1; fi

GITHUB_OWNER_NUMBER=0
while IFS= read -r -d '' GITHUB_OWNER; do
 if [[ -z "${GITHUB_OWNER}" ]]; then
  echo 'No owner!' >&2; exit 1
 elif [[ "${GITHUB_OWNER}" == '.' || "${GITHUB_OWNER}" == '..' || ! "${GITHUB_OWNER}" =~ ^[a-zA-Z0-9\._-]+$ ]]; then
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
 GITHUB_REPS_COUNT="$(STR_VALUE="${GITHUB_OWNER}" \
  yq -Mer -p=yml -o=yml '.github.reps[strenv(STR_VALUE)] | length' "${VCS_BACKUPS_CONFIG}")"
 if [[ $? != 0 ]]; then
  echo 'Get reps count error!' >&2; exit 1
 elif [[ ! "${GITHUB_REPS_COUNT}" =~ ^[1-9][0-9]?$ ]]; then
  echo 'Wrong reps count!' >&2; exit 1
 fi
 mapfile -d '' -t GITHUB_REPS < <(STR_VALUE="${GITHUB_OWNER}" \
  yq -Mer -0 -p=yml -o=yml '.github.reps[strenv(STR_VALUE)][]' "${VCS_BACKUPS_CONFIG}")
 if [[ ${#GITHUB_REPS[@]} -eq 0 ]]; then
  echo 'No reps!' >&2; exit 1; fi
 GITHUB_OWNER_NUMBER=$((GITHUB_OWNER_NUMBER+1))
 GITHUB_REP_NUMBER=0
 while IFS= read -r -d '' GITHUB_REP; do
  GITHUB_REP_NUMBER=$((GITHUB_REP_NUMBER+1))
  printf "%02d/%02d %s %02d/%02d %s"$'\n' "${GITHUB_OWNER_NUMBER}" "${GITHUB_OWNERS_COUNT}" "${GITHUB_OWNER}" "${GITHUB_REP_NUMBER}" "${GITHUB_REPS_COUNT}" "${GITHUB_REP}"
  :> "${STDERR}"
  "${VCS_BACKUPS_WORKDIR}/github_backups.sh" --repsdir "${VCS_BACKUPS_REPSDIR}" --owner "${GITHUB_OWNER}" --rep "${GITHUB_REP}" 2> "${STDERR}"
  if [[ $? != 0 ]]; then
   printf '%s' "Backup ${GITHUB_OWNER}/${GITHUB_REP} error!" | tee -a "${VCS_BACKUPS_LOGS}" >&2
   cat -- "${STDERR}" >> "${VCS_BACKUPS_LOGS}"
  fi
 done < <(printf '%s\0' "${GITHUB_REPS[@]}" | LC_ALL=C sort -z)
done < <(printf '%s\0' "${GITHUB_OWNERS[@]}" | LC_ALL=C sort -z)

#

if [[ -s "${VCS_BACKUPS_LOGS}" ]]; then
 echo "Some operations failed with errors: ${VCS_BACKUPS_LOGS}"
else
 rm "${VCS_BACKUPS_LOGS}"
fi

#
