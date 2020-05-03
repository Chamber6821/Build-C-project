#!/bin/bash

####################################################
#                                                  #
#  Please do not beat for the quality of the code  #
#                                                  #
#           ____               /))                 #
#          |;;/;:\____\|_____/:/ <                 #
#            | <:::::::::::::::> |                 #
#             \ ##:::::::::::## /                  #
#             /:::/~\:::::/~\:::\                  #
#            |##:| @ |:::| @ |:##|                 #
#            |{__}\_/ %%% \_/::::|                 #
#            |###:::::\_/:::::###|                 #
#             \:::::\__|__/:::::/                  #
#               \##::,___,::##/                    #
#                 /@@:::::@@\                      #
#               /###@::@@::###\                    #
####################################################

source options
echo "Args: ${BUILD_ARGS}"

mkdir -p "${RELEASE_FOLDER}" "${SOURCE_FOLDER}" "${OBJECTS_FOLDER}" "${LOG_FOLDER}" "${PROJECT_FOLDER}"

for A in $HEADER; do HEXPR="${HEXPR}(\.$A)"; done
for A in $SOURCE; do SEXPR="${SEXPR}(\.$A)"; done
unset HEADER SOURCE

compile() {
  local DIR=$(expr "$1" : "\([^/]*/\).*")
  local DIR2=$(expr "$1" : "$DIR\(.*/\).*")
  local FILE=$(expr "$1" : "${DIR}${DIR2}\(.*\)\..*$")
  local EXT=$(expr "$1" : ".*\.\(.*\)$")
  local LOG="${LOG_FOLDER}/${FILE}.${EXT}.log"
  
  local ARGS="$2"
  
  echo -E "Compile: ${FILE}.${EXT}"
  g++ ${ARGS} -c "$1" -o "${OBJECTS_FOLDER}/${FILE}.o" 2> $LOG
  
  local WARNINGS=$(grep -w 'warning:' $LOG | wc -l)
  local ERRORS=$(grep -w 'error:' $LOG | wc -l)
  local NOTES=$(grep -w 'note:' $LOG | wc -l)
  
  if [[ ${ERRORS} != 0 ]] || [[ ${NOTES} != 0 ]]; then
    echo ${DIR2}${FILE}.${EXT}: ${WARNINGS} warning, ${ERRORS} error, ${NOTES} note
    echo "${DIR2}${FILE}.${EXT}" >> ${ERROR_LIST_FILES}
  else
    echo ${FILE}.${EXT}: ${WARNINGS} warning - OK
    if [[ ${WARNINGS} != 0 ]]; then
      echo "${DIR2}${FILE}.${EXT}" >> ${WARNING_LIST_FILES}
    fi
  fi
}

countp() {
  local process=$(ps -o ppid | grep $$ | wc -l)
  echo $((process - 1))
}

check_deps() {
  declare -A table_headers
  for SOURCE in ${!table[@]}; do
    for HEADER in ${table[$SOURCE]}; do
      table_headers[$HEADER]="${table_headers[${HEADER}]}${SOURCE} "
    done
  done
  
  MARK_DEPS=
  for HEADER in ${!table_headers[@]}; do
    if ! was_edit ${SOURCE_FOLDER}${HEADER}; then continue; fi
    for SOURCE in ${table_headers[$HEADER]}; do
      MARK_DEPS="${MARK_DEPS}${SOURCE} "
    done
    update_time ${SOURCE_FOLDER}${HEADER}
  done
}

SCRIPT_FOLDER="$(dirname "$(readlink -e "$0")")/"
source ${SCRIPT_FOLDER}/deptable.sh
source ${SCRIPT_FOLDER}/edittime.sh

declare -A files # Файлы для компиляции (ключи)
>> ${PROJECT_FOLDER}/deptable; >> ${PROJECT_FOLDER}/edittime # Создаем файлы, если нет
load_deptable ${PROJECT_FOLDER}/deptable # Загрузка таблицы зависимостей
load_timetable ${PROJECT_FOLDER}/edittime # Загрузка таблицы времени последнего изменения



SOURCE_FILES=$(ls ${SOURCE_FOLDER} | grep ".*[${SEXPR}]$") # Файлы реализации
HEADER_FILES=$(ls ${SOURCE_FOLDER} | grep ".*[${HEXPR}]$") # Заголовки


# Помечаем исходникик
for FILE in ${SOURCE_FILES}; do
  if was_edit ${SOURCE_FOLDER}${FILE} || [[ ! -f ${OBJECTS_FOLDER}${FILE%.*}.o ]]; then
    files[${FILE}]=
    update_time ${SOURCE_FOLDER}${FILE}
  fi
done

# Помечаем файлы для компиляции (по зависимостям)
check_deps # Сохраняет имена файлов в MARK_DEPS
for SOURCE in ${MARK_DEPS}; do files[${SOURCE}]=; done

upload_deptable ${PROJECT_FOLDER}/deptable &
upload_timetable ${PROJECT_FOLDER}/edittime &


# Компиляция файлов
> $ERROR_LIST_FILES
> $WARNING_LIST_FILES
for FILE in ${!files[@]}; do
  while [[ $(countp) -ge ${PROCESS_MAX} ]]; do sleep 0.1; done
  compile ${SOURCE_FOLDER}${FILE} "${BUILD_ARGS}" &
done
wait


# Вывод сообщений компилятора
LINK=true
if [[ $(stat -c %s ${ERROR_LIST_FILES}) -gt 0 ]]; then
  LINK=false
  echo "============================"
  echo "====| Errors and Notes |===="
  echo "============================"
  IFS=$'\n'
  for FILE in $(cat ${ERROR_LIST_FILES}); do
    echo "File: ${FILE}"
    cat $LOG_FOLDER/$FILE.log
    echo "============================"
  done
fi

if [[ $(stat -c %s ${WARNING_LIST_FILES}) -gt 0 ]]; then
  if [[ LINK=false ]]; then echo "----------------------------"; fi
  echo "============================"
  echo "========| Warnings |========"
  echo "============================"
  IFS=$'\n'
  for FILE in $(cat ${WARNING_LIST_FILES}); do
    echo "File: ${FILE}"
    cat $LOG_FOLDER/$FILE.log
    echo "============================"
  done
fi
unset IFS


# Линковка
if [[ $LINK == "true" ]]; then
  echo "Linking. . ."
  g++ ${OBJECTS_FOLDER}/*.o -o ${RELEASE_FOLDER}/file.out ${BUILD_ARGS}
  ERROR_CODE=$?
  if [[ ${ERROR_CODE} = 0 ]]; then
    echo "Done"
    #exit 0
  else
    echo "Link error"
    echo "Error code: ${ERROR_CODE}"
    #exit ${ERROR_CODE}
  fi
else
  echo "Build error"
  #exit 1;
fi

