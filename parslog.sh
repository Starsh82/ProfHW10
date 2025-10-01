#!/bin/bash

#бесконечный цикл для теста
# while true
# do
# 	echo "бесконечный цикл"
# 	sleep 5
# done

lasttime='' #Последнее записанное время
stracs='' #Строка для передачи в awk
time_start=0 #Время начала в логе для вывода статистики за час
time_end=0 #Время окончания в логе для вывода статистики за час
time_line=0 #время в обрабатываемой строке

logname="/home/starsh/access1hour.log" # файл со строками из основгого лога за 1 час
var_access="/home/starsh/access.log" # основной лог файл
var_time_pars="/home/starsh/time_pars"
var_mailstat="/home/starsh/mailstat"

#Преобразование даты в секунды, из-за несовпадение локалей дата в логе не преобразуется с помощью date, пришлось изращаться
#echo "14/Aug/2019:04:12:10" | sed 's/:/ /' | awk -F'[/ ]' '
translate_date () {
    awk -v str="$stracs" -F'[][]' '{print $2}' | awk '{print $1}' | sed 's/:/ /' | awk -F'[/ ]' '
    {
        # Создаем массив с номерами месяцев
        months["Jan"] = "01"; months["Feb"] = "02"; months["Mar"] = "03";
        months["Apr"] = "04"; months["May"] = "05"; months["Jun"] = "06";
        months["Jul"] = "07"; months["Aug"] = "08"; months["Sep"] = "09";
        months["Oct"] = "10"; months["Nov"] = "11"; months["Dec"] = "12";
        
        printf "%s-%s-%s %s\n", $3, months[$2], $1, $4
    }' | xargs -I {} date -d "{}" +%s
}

#Парсинг 1 часа из лога в случает если отсутствует запомненное время
pars1hour () {
	time_start="$(sed -n '1p' time_pars)"
	let "time_end=$time_start+3600"
	time_line=0
	while IFS= read -r stracs
	do
		time_line="$(echo "$stracs" | translate_date)"
	#	разница в условии от pars1hour0 -gt вместо 
		if [ "$time_line" -gt "$time_start" ] && [ "$time_line" -le "$time_end" ]; then
			echo $stracs
			echo $time_line > time_pars
		fi
		if [ "$time_line" -gt "$time_end" ]; then
			echo $time_line > time_pars # запись времени из строки следующей за последней строкой в часе
			break
		fi
	done < access.log
}

# Вывод статистики из лога
parsing () {
	echo "Наибольшее количество запросов было со следующих IP адресов"
	awk '{print $1}' "$logname" | sort | uniq -c | sort -nr | head
	echo
	echo
	echo "Список запрашиваемых URL (с наибольшим кол-вом запросов)"
	grep -Eo "(https?|ftp)://[a-zA-Z0-9./?=_:@~#%&;+$!*',-]+" "$logname" | sort | uniq -c | sort -nr | head
	echo
	echo
	echo "Ошибки веб-сервера/приложения c момента последнего запуска"
	#grep -Eo ' [4-5][0-5,9][0-5,9] [0-9]{3}' "$logname" | awk '{print $1}' | sort | uniq -c | sort -nr
	grep -Eo ' [4-5][0-5,9][0-5,9] [0-9]{3}' "$logname" | awk '{print $1}' | sort | uniq
	echo
	echo
	echo "Список всех кодов HTTP ответа с указанием их кол-ва"
	grep -Eo ' [1-5][0-5,9][0-9] [0-9]{1,} ' "$logname" | awk '{print $1}' | sort | uniq -c | sort -nr
}

# Функция псевдоотправки письма
sendmail () {
	time1="$(head -n 1 "$logname" | translate_date)"
	time2="$(tail -n 1 "$logname" | translate_date)"
	echo "Время начала обрабатываемого диапазона:" > "$var_mailstat"
	TZ=Europe/Moscow date -d "@$time1" >> "$var_mailstat"
	parsing >> mailstat # файл с письмом для отправки
	echo "Время окончания обрабатываемого диапазона:" >> "$var_mailstat"
	TZ=Europe/Moscow date -d "@$time2" >> "$var_mailstat"
	cp mailstat "mailstat_$(date +"%Y%m%d_%H%M%S")"
}

#Проверка запущен ли в данный момент скрипт
#if [ -n "$(pgrep -f 'parslog.sh' | grep -v $$)" ]
if [ "$(pgrep -f "/home/starsh/parslog.sh")" != "$(echo $$)" ]; then
	echo "Срипт parslog.sh уже запущен"
	exit 1
else
	#Файл для хранения последней даты обработки time_pars
	#Если файла time_pars не существует или он пустой, то записываем в него время из первой строки access.log
	if ! ([ -f "$var_time_pars" ] || [ -s "$var_time_pars" ]); then
		stracs="$(sed -n '1p' "$var_access")"
		echo "$stracs" | translate_date > "$var_time_pars"
		head -n 1 "$var_access" > "$logname"
		pars1hour >> "$logname"
		sendmail
	else
		pars1hour > "$logname"
		sendmail
	fi
fi