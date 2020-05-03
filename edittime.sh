#!/bin/bash

was_edit() {
  if [[ ! -f ${1} ]]; then return 0; fi
  [[ timetable[$1] -lt $(stat -c %Z ${1}) ]]
}

update_time() {
  timetable[${1}]=$(stat -c %Z ${1})
  return 0;
}

load_timetable() {
  timetable=()
  local IFS=$'\n'
  for LINE in $(cat ${1}); do
    KEY=$(expr "${LINE}" : "\(.*\) ")
    VAL=$(expr "${LINE}" : ".* \([0-9]*\)")
    timetable[$KEY]=$VAL
  done
}

upload_timetable() {
  > $1
  for KEY in ${!timetable[@]}; do
    #echo "KEY = $KEY; VAL = ${timetable[${KEY}]}"
    echo ${KEY} ${timetable[${KEY}]} >> $1
  done
}

declare -Ax timetable
declare -fx was_edit
declare -fx update_time
declare -fx load_timetable
declare -fx upload_timetable
