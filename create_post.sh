#!/usr/bin/env bash

export LANG=C.UTF-8

if [[ -z "${1// }" ]]; then
  /bin/cat << EOF
Usage:
  ${0} [post name]

Examples:
  Create new post
  \$ ${0} my_first_post
EOF
  exit
fi

hugo new content "posts/$(date '+%Y')/${1// }/${1// }.md"
