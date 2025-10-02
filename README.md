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

logname="/home/starsh/access1hour.log" # файл со строками из основгого лога за 1 час
var_access="/home/starsh/access.log" # основной лог файл
var_time_pars="/home/starsh/time_pars" # время начала следующего временного отрезка
var_mailstat="/home/starsh/mailstat" # файл со статистикой для отправки

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
	time_start="$(sed -n '1p' "$var_time_pars")"
	let "time_end=$time_start+3600"
	time_line=0
	while IFS= read -r stracs
	do
		time_line="$(echo "$stracs" | translate_date)"
	#	разница в условии от pars1hour0 -gt вместо 
		if [ "$time_line" -gt "$time_start" ] && [ "$time_line" -le "$time_end" ]; then
			echo $stracs
			echo $time_line > "$var_time_pars"
		fi
		if [ "$time_line" -gt "$time_end" ]; then
			echo $time_line > "$var_time_pars" # запись времени из строки следующей за последней строкой в часе
			break
		fi
	done < "$var_access"
}

# Вывод статистики из лога
parsing () {
	#logname="access1hour.log" # файл со строками из основгого лога за 1 час
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
	parsing >> "$var_mailstat" # файл с письмом для отправки
	echo "Время окончания обрабатываемого диапазона:" >> "$var_mailstat"
	TZ=Europe/Moscow date -d "@$time2" >> "$var_mailstat"
	cp "$var_mailstat" "/home/starsh/mailstat_$(date +"%Y%m%d_%H%M%S")"
}

#Проверка запущен ли в данный момент скрипт
#if [ -n "$(pgrep -f 'parslog.sh' | grep -v $$)" ]
# if pgrep -f '/home/starsh/parslog.sh' | grep -v $$ | grep -q .; then
if PID=`pgrep -x "parslog.sh"`
then
	echo "Срипт $PID уже запущен!"
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
```
---
Пример данные из промежуточного лог файла access1hour.log с записями за 1 час
```
62.75.198.172 - - [14/Aug/2019:11:00:25 +0300] "POST /wp-cron.php?doing_wp_cron=1565769624.2795310020446777343750 HTTP/1.1" 200 31 "https://dbadmins.ru/wp-cron.php?doing_wp_cron=1565769624.2795310020446777343750" "WordPress/5.0.4; https://dbadmins.ru"rt=0.595 uct="0.000" uht="0.595" urt="0.595"
93.158.167.130 - - [14/Aug/2019:11:00:25 +0300] "GET / HTTP/1.1" 200 14475 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=1.099 uct="0.000" uht="1.014" urt="1.099"
104.243.26.147 - - [14/Aug/2019:11:02:09 +0300] "GET /wp-login.php HTTP/1.1" 200 1338 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0)
Gecko/20100101 Firefox/62.0"rt=0.198 uct="0.000" uht="0.198" urt="0.198"
104.243.26.147 - - [14/Aug/2019:11:02:10 +0300] "POST /wp-login.php HTTP/1.1" 200 1721 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.347 uct="0.000" uht="0.197" urt="0.197"
104.243.26.147 - - [14/Aug/2019:11:02:11 +0300] "POST /xmlrpc.php HTTP/1.1" 200 292 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.387 uct="0.000" uht="0.245" urt="0.245"
87.250.233.68 - - [14/Aug/2019:11:04:50 +0300] "GET /robots.txt HTTP/1.1" 200 626 "-" "Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:11:04:54 +0300] "GET /2017/05/19/%D0%BC%D0%BE%D0%BD%D0%B8%D1%82%D0%BE%D1%80%D0%B8%D0%BD%D0%B3-%D0%B1%D1%8D%D0%BA%D0%B0%D0%BF%D0%BE%D0%B2/ HTTP/1.1" 200 10671 "-" "Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)"rt=0.250 uct="0.000"
uht="0.192" urt="0.250"
41.226.27.17 - - [14/Aug/2019:11:17:49 +0300] "GET /wp-login.php HTTP/1.1" 200 1338 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.196 uct="0.000" uht="0.196" urt="0.196"
41.226.27.17 - - [14/Aug/2019:11:17:49 +0300] "POST /wp-login.php HTTP/1.1" 200 1721 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.249 uct="0.000" uht="0.200" urt="0.200"
41.226.27.17 - - [14/Aug/2019:11:17:50 +0300] "POST /xmlrpc.php HTTP/1.1" 200 292 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.315 uct="0.000" uht="0.254" urt="0.254"
87.250.233.68 - - [14/Aug/2019:11:32:44 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
45.119.80.34 - - [14/Aug/2019:11:32:49 +0300] "GET /wp-login.php HTTP/1.1" 200 1338 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.224 uct="0.000" uht="0.224" urt="0.224"
45.119.80.34 - - [14/Aug/2019:11:32:51 +0300] "POST /wp-login.php HTTP/1.1" 200 1721 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.444 uct="0.000" uht="0.198" urt="0.198"
45.119.80.34 - - [14/Aug/2019:11:32:52 +0300] "POST /xmlrpc.php HTTP/1.1" 200 292 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.504 uct="0.000" uht="0.248" urt="0.248"
141.8.141.136 - - [14/Aug/2019:11:33:32 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
77.247.110.201 - - [14/Aug/2019:11:56:29 +0300] "GET /admin/config.php HTTP/1.1" 404 3652 "-" "curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.27.1 zlib/1.2.3 libidn/1.18 libssh2/1.4.2"rt=0.000 uct="-" uht="-" urt="-"
64.20.39.18 - - [14/Aug/2019:11:57:06 +0300] "GET /wp-login.php HTTP/1.1" 200 1338 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.203 uct="0.000" uht="0.203" urt="0.203"
64.20.39.18 - - [14/Aug/2019:11:57:07 +0300] "POST /wp-login.php HTTP/1.1" 200 1721 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.353 uct="0.000" uht="0.203" urt="0.203"
64.20.39.18 - - [14/Aug/2019:11:57:08 +0300] "POST /xmlrpc.php HTTP/1.1" 200 292 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:62.0) Gecko/20100101 Firefox/62.0"rt=0.326 uct="0.000" uht="0.246" urt="0.246"
62.75.198.172 - - [14/Aug/2019:11:57:30 +0300] "POST /wp-cron.php?doing_wp_cron=1565773050.3219890594482421875000 HTTP/1.1" 200 31 "https://dbadmins.ru/wp-cron.php?doing_wp_cron=1565773050.3219890594482421875000" "WordPress/5.0.4; https://dbadmins.ru"rt=0.322 uct="0.000" uht="0.322" urt="0.322"
62.210.252.196 - - [14/Aug/2019:11:57:30 +0300] "POST /wp-admin/admin-post.php?page=301bulkoptions HTTP/1.1" 200 31 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.670 uct="0.000" uht="0.670" urt="0.670"
62.210.252.196 - - [14/Aug/2019:11:57:31 +0300] "POST /wp-admin/admin-ajax.php?page=301bulkoptions HTTP/1.1" 400 11 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.236 uct="0.000" uht="0.236" urt="0.236"
62.210.252.196 - - [14/Aug/2019:11:57:31 +0300] "POST / HTTP/1.1" 200 14475 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.274 uct="0.000" uht="0.188" urt="0.274"
62.210.252.196 - - [14/Aug/2019:11:57:32 +0300] "GET /1 HTTP/1.1" 404 29500 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0"rt=0.540 uct="0.000" uht="0.183" urt="0.540"
62.210.252.196 - - [14/Aug/2019:11:57:33 +0300] "POST /wp-admin/admin-post.php?page=301bulkoptions HTTP/1.1" 301 185 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.000 uct="-" uht="-" urt="-"
62.210.252.196 - - [14/Aug/2019:11:57:34 +0300] "GET /wp-admin/admin-post.php?page=301bulkoptions HTTP/1.1" 200 31 "http://dbadmins.ru/wp-admin/admin-post.php?page=301bulkoptions" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.291 uct="0.000" uht="0.291" urt="0.291"
62.210.252.196 - - [14/Aug/2019:11:57:34 +0300] "POST /wp-admin/admin-ajax.php?page=301bulkoptions HTTP/1.1" 301 185 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.000 uct="-" uht="-" urt="-"
62.210.252.196 - - [14/Aug/2019:11:57:34 +0300] "GET /wp-admin/admin-ajax.php?page=301bulkoptions HTTP/1.1" 400 11 "http://dbadmins.ru/wp-admin/admin-ajax.php?page=301bulkoptions" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.232 uct="0.000" uht="0.232" urt="0.232"
62.210.252.196 - - [14/Aug/2019:11:57:34 +0300] "POST / HTTP/1.1" 301 185 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.000 uct="-" uht="-" urt="-"
62.210.252.196 - - [14/Aug/2019:11:57:35 +0300] "GET / HTTP/1.1" 200 14475 "http://dbadmins.ru" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.311 uct="0.000" uht="0.188" urt="0.311"
62.210.252.196 - - [14/Aug/2019:11:57:35 +0300] "GET /1 HTTP/1.1" 301 185 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0"rt=0.011 uct="-" uht="-" urt="-"
62.210.252.196 - - [14/Aug/2019:11:57:35 +0300] "GET /1 HTTP/1.1" 404 29500 "http://dbadmins.ru/1" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0"rt=0.262 uct="0.000" uht="0.212" urt="0.262"
60.208.103.154 - - [14/Aug/2019:11:59:33 +0300] "GET /manager/html HTTP/1.1" 404 3652 "-" "User-Agent:Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705"rt=0.000 uct="-" uht="-" urt="-"
60.208.103.154 - - [14/Aug/2019:11:59:33 +0300] "\x16\x03\x01\x00Z\x01\x00\x00V\x03\x01]S\xCD{\xA0\xFF\x0F\x93B\x04\x97\x8B|2i\x17\xE44Z\xAD\xE9\x2243B\x85E6b\xB1{\xB6\x00\x00\x18\x00/\x005\x00\x05\x00" 400 173 "-" "-"rt=0.189 uct="-" uht="-" urt="-"
60.208.103.154 - - [14/Aug/2019:11:59:33 +0300] "\x16\x03\x01\x00Z\x01\x00\x00V\x03\x01]S\xCD{\x8D\xA5\xE6\xAD\xDE&\x18\xC9\xDA\xB1\xCA\xE1\xE2\x05\x83\x00\xDE/\xB3G\x18j\x85\xC7\xBD\xDEvp\x00\x00\x18\x00/\x005\x00\x05\x00" 400 173 "-" "-"rt=0.194 uct="-" uht="-" urt="-"
```
---
Результирующий файл mailstat со статистикой по логу ("письмо со статисткой за час")
```
Время начала обрабатываемого диапазона:
Ср 14 авг 2019 10:00:25 MSK
Наибольшее количество запросов было со следующих IP адресов
     12 62.210.252.196
      3 87.250.233.68
      3 64.20.39.18
      3 60.208.103.154
      3 45.119.80.34
      3 41.226.27.17
      3 104.243.26.147
      2 62.75.198.172
      1 93.158.167.130
      1 77.247.110.201


Список запрашиваемых URL (с наибольшим кол-вом запросов)
      5 http://yandex.com/bots
      2 https://dbadmins.ru
      1 https://dbadmins.ru/wp-cron.php?doing_wp_cron=1565773050.3219890594482421875000
      1 https://dbadmins.ru/wp-cron.php?doing_wp_cron=1565769624.2795310020446777343750
      1 http://dbadmins.ru/wp-admin/admin-post.php?page=301bulkoptions
      1 http://dbadmins.ru/wp-admin/admin-ajax.php?page=301bulkoptions
      1 http://dbadmins.ru/1
      1 http://dbadmins.ru


Ошибки веб-сервера/приложения c момента последнего запуска
400
404


Список всех кодов HTTP ответа с указанием их кол-ва
     21 200
      6 404
      4 400
      4 301
Время окончания обрабатываемого диапазона:
Ср 14 авг 2019 10:59:33 MSK
```
