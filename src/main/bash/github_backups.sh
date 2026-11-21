#!/usr/local/bin/bash

unset GITHUB_OWNER
unset GITHUB_REP
unset VCS_BACKUPS_REPSDIR

while [[ $# -gt 0 ]]; do
 if [[ $# -lt 2 ]]; then echo 'Wrong flags!' >&2; exit 1; fi
 case "$1" in
  '--owner')
   if [[ -v GITHUB_OWNER ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   GITHUB_OWNER="$2"; shift 2;;
  '--rep')
   if [[ -v GITHUB_REP ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   GITHUB_REP="$2"; shift 2;;
  '--repsdir')
   if [[ -v VCS_BACKUPS_REPSDIR ]]; then echo "\"$1\" already used!" >&2; exit 1; fi
   VCS_BACKUPS_REPSDIR="$2"; shift 2;;
  *) echo "\"$1\" is not supported!" >&2; exit 1;;
 esac
done

#

if [[ -z "${GITHUB_OWNER}" ]]; then
 echo 'No owner!' >&2; exit 1
elif [[ ! "${GITHUB_OWNER}" =~ ^(_|-|[a-z]|[A-Z]|[0-9])(_|-|\.|[a-z]|[A-Z]|[0-9])*$ ]]; then
 echo 'Wrong owner!' >&2; exit 1
fi

#

if [[ -z "${GITHUB_REP}" ]]; then
 echo 'No rep!' >&2; exit 1
elif [[ ! "${GITHUB_REP}" =~ ^(_|-|[a-z]|[A-Z]|[0-9])(_|-|\.|[a-z]|[A-Z]|[0-9])*$ ]]; then
 echo 'Wrong rep!' >&2; exit 1
fi

#

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

#

GITHUB_OWNER_DIR="${VCS_BACKUPS_REPSDIR}/${GITHUB_OWNER}"
if [[ -L "${GITHUB_OWNER_DIR}" ]]; then
 echo "\"${GITHUB_OWNER_DIR}\" is a symlink!" >&2; exit 1
elif [[ -e "${GITHUB_OWNER_DIR}" ]]; then
 if [[ ! -d "${GITHUB_OWNER_DIR}" ]]; then
  echo "\"${GITHUB_OWNER_DIR}\" is not a dir!" >&2; exit 1; fi
else
 echo "\"${GITHUB_OWNER_DIR}\" does not exist!" >&2; exit 1
fi

if [[ ! -d "${GITHUB_OWNER_DIR}/${GITHUB_REP}.git" ]]; then
 VCS_BACKUPS_DST="$(mktemp -d)" || exit 1
 VCS_BACKUPS_ORIGIN="https://github.com/${GITHUB_OWNER}/${GITHUB_REP}.git"
 #
 echo "Git init ${GITHUB_OWNER}/${GITHUB_REP}..."
 git init --quiet --bare "${VCS_BACKUPS_DST}"
 if [[ $? != 0 ]]; then
  echo "Git init ${GITHUB_OWNER}/${GITHUB_REP} error!" >&2; exit 1; fi
 #
 git -C "${VCS_BACKUPS_DST}" remote add origin "${VCS_BACKUPS_ORIGIN}"
 if [[ $? != 0 ]]; then
  echo "Git remote add \"${VCS_BACKUPS_ORIGIN}\" error!" >&2; exit 1; fi
 #
 git -C "${VCS_BACKUPS_DST}" config --local gc.auto 0 \
  && git -C "${VCS_BACKUPS_DST}" config --local gc.pruneExpire never
 if [[ $? != 0 ]]; then
  echo "Git config ${GITHUB_OWNER}/${GITHUB_REP} error!" >&2; exit 1; fi
 #
 mv "${VCS_BACKUPS_DST}" "${GITHUB_OWNER_DIR}/${GITHUB_REP}.git"
 if [[ $? != 0 ]]; then
  echo "Move ${GITHUB_OWNER}/${GITHUB_REP} error!" >&2; exit 1; fi
fi

echo "Git fetch ${GITHUB_OWNER}/${GITHUB_REP}..."
git -C "${GITHUB_OWNER_DIR}/${GITHUB_REP}.git" fetch --quiet --prune --tags --force origin
if [[ $? != 0 ]]; then
 echo "Git fetch ${GITHUB_OWNER}/${GITHUB_REP} error!" >&2; exit 1; fi

#
