# ProfHW10
Написать скрипт на языке Bash для парсинга access.log  
В связи с тем, что это учебная задача, то парсинг лога в разрезе времени пришлось сделать не очень логично.  
Для реальной задачи надо было бы получать текущее время и делать выборку из лога за последний прошедший час, но в условиях наличия статического лога сделанного за прошлый период времени, пришлось изменить логику работы скрипта. Скрипт начинает выводить статитстику начиная с первой записи в логе отсчитывая 1 час вперёд, "запоминая" поледнее время. При каждом запуске он парсит лог начиная со времени окончания предыдущей группы строк из лога (не знаю как написать более понятно). В общем коряво, нелогично, бесполезно, но подругому я не придумал. :)  

<b>parslog.sh</b>
```
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
	logname="access1hour.log" # файл со строками из основгого лога за 1 час
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
	time1="$(head -n 1 access1hour.log | translate_date)"
	time2="$(tail -n 1 access1hour.log | translate_date)"
	echo "Время начала обрабатываемого диапазона:" > mailstat
	TZ=Europe/Moscow date -d "@$time1" >> mailstat
	parsing >> mailstat # файл с письмом для отправки
	echo "Время окончания обрабатываемого диапазона:" >> mailstat
	TZ=Europe/Moscow date -d "@$time2" >> mailstat
	cp mailstat "mailstat_$(date +"%Y%m%d_%H%M%S")"
}

#Проверка запущен ли в данный момент скрипт
#if [ -n "$(pgrep -f 'parslog.sh' | grep -v $$)" ]
if [ "$(pgrep -f "parslog.sh")" != "$(echo $$)" ]; then
	echo "Срипт parslog.sh уже запущен"
	exit 1
else
	#Файл для хранения последней даты обработки time_pars
	#Если файла time_pars не существует или он пустой, то записываем в него время из первой строки access.log
	if ! ([ -f "time_pars" ] || [ -s "time_pars" ]); then
		stracs="$(sed -n '1p' access.log)"
		echo "$stracs" | translate_date > time_pars
		head -n 1 access.log > access1hour.log
		pars1hour >> access1hour.log
		sendmail
	else
		pars1hour > access1hour.log
		sendmail
	fi
fi
```
---





<b>p1.sh</b>  
```
#!/bin/bash

lasttime='' #Последнее записанное время
stracs='' #Строка для передачи в awk
time_start='' #Время начала в логе для вывода статистики за час
time_end='' #Время окончания в логе для вывода статистики за час
time_line=0 #время в обрабатываемой строке

#Преобразование даты в секунды
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
	#echo $str
	#echo $stracs
}

#Парсинг 1 часа из лога
pars1hour () {
	 #echo "Существует"
	time_start="$(sed -n '1p' time_pars)"
	let "time_end=$time_start+3600"

	# надо что-то сделать с time_line, не надо присваивать ему 0. Первое условие вощзможно лишнее. Надо что-то сделать с первой и последней стоками
	time_line=0
	while IFS= read -r stracs
	do
		time_line="$(echo "$stracs" | translate_date)"
	#	echo $time_line > time_pars
		if [ "$time_line" -ge "$time_start" ] && [ "$time_line" -le "$time_end" ]; then
			echo $stracs
			echo $time_line > time_pars

		fi
		if [ "$time_line" -gt "$time_end" ]; then exit; fi
		#Пока $time_line больше $time_start и меньше либо равно time_end
		# if [ "$time_line" -lt "$time_start" ]; then
		# 	if [ "$time_line" -eq 0 ]; then #Происходит 1 раз в случае если time_pars не существует или пустой
		# 		echo $stracs
		# 	fi
		# 	time_line="$(echo "$stracs" | translate_date)"

		# elif [ "$time_line" -ge "$time_start" ] && [ "$time_line" -le "$time_end" ]; then
		# 	time_line="$(echo "$stracs" | translate_date)"
		# 	echo $time_line > time_pars
		# 	echo $stracs
		# else 
		# 	#echo $time_line > time_pars
		# 	exit
		# fi
		#cat access.log > access_test.log
		#read -r line
		#echo 
	done < access.log
#	echo $time_line > time_pars
}

#Файл для хранения последней даты обработки time_pars
#Если файла time_pars не существует или он пустой, то записываем в него время из первой строки access.log
if ! ([ -f "time_pars" ] || [ -s "time_pars" ]); then
    stracs="$(sed -n '1p' access.log)"
    echo "$stracs" | translate_date > time_pars
	#time_line="$(echo "$stracs" | translate_date)"

	pars1hour > access1hour.log
	#echo $time_line > ./time_pars
else
   pars1hour > access1hour.log
   #echo $time_line > ./time_pars
fi
#echo $time_line
```
---






<b>translate_time.sh</b>
```
#!/bin/bash

stracs="$(sed -n '1p' oneline)"

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
echo "$stracs" | translate_date
#translate_date
#echo "$stracs"
```
---
```
awk -F'[][]' '{print $2}' access.log | head
```
