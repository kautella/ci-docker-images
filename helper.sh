#!/bin/bash
# helper script to only build/test changed docker images, improving the pipeline velocity for branch builds
# it will run all the images on the main branch
set -eo pipefail

RED=$(printf '\e[31m')
GREEN=$(printf '\e[32m')
BLUE=$(printf '\e[34m')
CYAN=$(printf '\e[36m')
RESET=$(printf '\e[39m')

DOCKER_REPO="198136261100.dkr.ecr.eu-west-1.amazonaws.com/circleci-runners"

# 1. image folder
helper::build () {
    local image=$1
    local name="${DOCKER_REPO}:${image}"
    local version=$(helper::get_version "${1}")
    docker build \
        --build-arg BUILD_VERSION=${version} \
        -t ${name}-${version} \
        ${image}
}

# 1. image folder
helper::get_version () {
    local image=$1
    local version=$(cat "${image}/VERSION")
    echo $version
}

# 1. image folder
helper::push () {
    local image=$1
    local version=$(helper::get_version "${1}")
    helper::push::tag ${image} ${version}
}

# 1. image folder
# 2. target version
helper::push::tag () {
    local name="${DOCKER_REPO}:${1}"
    local tag=${2}
    aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 198136261100.dkr.ecr.eu-west-1.amazonaws.com
    docker push ${name}-${tag}
}

# 1. image folder
helper::execute() {
    local image=$1
    [ "${changed_images[${image}]}" == "" ] || return 0
    echo "${BLUE}-----------------------------------${RESET}"
    echo "${GREEN}${ACTION^} [${image}]${RESET}"
    helper::${ACTION} ${image} | sed -e "s/^/${CYAN}[${image}]${RESET} /"
    echo "${BLUE}-----------------------------------${RESET}"
}

# error handler - allow full run for better multi error report
ERROR_COUNT=0
helper::error() {
    ERROR_COUNT=$((1+${ERROR_COUNT}))
    >&2 echo "${RED}new error found. total: ${ERROR_COUNT}${RESET}"
}

[ -z ${1} ] && echo "missing action(build, test, push)" && exit 1 || true
ACTION=$1
TARGET_IMAGE=${2}

[ -z ${CI_COMMIT_REF_NAME} ] && CI_COMMIT_REF_NAME=$(git rev-parse --abbrev-ref HEAD) || true

# if on main, build the images from HEAD and HEAD~1
# if on another branch, build the difference between branch and main
if [ ${CI_COMMIT_REF_NAME} = 'main' ]
then REF_NAME='HEAD~1'
fi
CHANGED_FILES=$(git diff --name-only $(git merge-base $(git rev-parse ${REF_NAME:-HEAD}) main)|grep -v README) || true
echo "changed files: ${CHANGED_FILES}"

trap helper::error ERR

# get changed images
declare -A changed_images
if [ -z "${TARGET_IMAGE}" ];then
    for file in $(ls -d */); do
        if [[ "${CHANGED_FILES}" =~ ${file} ]]; then
            changed_images[${file%%/*}]=""
        fi
    done
elif [ "all" = "${TARGET_IMAGE}" ];then
    for file in $(ls -d */); do
        changed_images[${file%%/*}]=""
    done
else
    for single in $(echo ${TARGET_IMAGE//,/ }); do
        changed_images[${single}]=""
    done
fi

# execute action
if ! type helper::${ACTION} &> /dev/null; then
    echo "invalid command"
    exit 1
elif [[ -v "${!changed_images[@]}" ]]; then
    echo "no images to build"
else
    for image in "${!changed_images[@]}"; do
        helper::execute ${image}
    done
    exit ${ERROR_COUNT}
fi
