#!/bin/bash

to_set() {
  declare -A arr
  while [[ -n $1 ]]; do
    arr["${1}"]=
    shift
  done
  echo ${!arr[@]}
  return 0;
}

get_deps() {
  #if [[ $# -lt 1 ]] || [[ ! -f $1 ]]; then return 1; fi
  local IFS=$'\n'
  for LINE in $(grep "#include\s*\".*\"" "./${1}"); do
    echo -n "$(expr "${LINE}" : ".*\"\(.*\)\".*") "
  done
  return 0;
}

load_deptable() {
  #if [[ $# -lt 1 ]] || [[ ! -f ${1} ]]; then return 1; fi
  table=()
  local IFS=$'\n'
  for LINE in $(cat "${1}"); do
    local field_name=$(expr "${LINE}" : "^\s*\(.*\)\s*:")
    local field_value=$(expr "${LINE}" : ".*{\(.*\)}.*")
    table[$field_name]=$(to_set ${field_value})
  done
  return 0;
}

update_deptable() {
  #if [[ $# -lt 1 ]] || [[ ! -f ${1} ]]; then return 1; fi
  local A=$(expr "${1}" : "^.*/\(.*\)") # отрезаем первую директорию из пути
  table[${A}]=$(to_set $(get_deps ${1}))
  return 0;
}

upload_deptable() {
  #if [[ $# -lt 1 ]]; then return 1; fi
  > $1
  for KEY in ${!table[@]}; do
    echo ${KEY}:{${table[${KEY}]}} >> $1
  done
  return 0;
}

declare -Ax table
declare -fx get_deps
declare -fx load_deptable
declare -fx update_deptable
declare -fx upload_deptable

declare -fx to_set
