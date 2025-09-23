# ProfHW10
Написать скрипт на языке Bash для парсинга access.log  
В связи с тем, что это учебная задача, то парсинг лога в разрезе времени пришлось сделать не очень логично.  
Для реальной задачи надо было бы получать текущее время и делать выборку из лога за последний прошедший час, но в условиях наличия статического лога сделанного за прошлый период времени, пришлось изменить логику работы скрипта. Скрипт начинает выводить статитстику начиная с первой записи в логе отсчитывая 1 час вперёд, "запоминая" поледнее время. При каждом запуске он парсит лог начиная со времени окончания предыдущей группы строк из лога (не знаю как написать более понятно). В общем коряво, нелогично, бесполезно, но подругому я не придумал. :)  

<b>parslog.sh</b>
```
#!/bin/bash

#бесконечный цикл для теста
#while true
#do
#	echo "бесконечный цикл"
#	sleep 5
#done

#Функция для изменения формата даты.
translate_date () {
	echo "14/Aug/2019:04:12:10" | sed 's/:/ /' | awk -F'[/ ]' '
	{
    # Создаем массив с номерами месяцев
    months["Jan"] = "01"; months["Feb"] = "02"; months["Mar"] = "03";
    months["Apr"] = "04"; months["May"] = "05"; months["Jun"] = "06";
    months["Jul"] = "07"; months["Aug"] = "08"; months["Sep"] = "09";
    months["Oct"] = "10"; months["Nov"] = "11"; months["Dec"] = "12";
    
    printf "%s-%s-%s %s\n", $3, months[$2], $1, $4
	}'
}

parsing () {
	echo "Наибольшее количество запросов было со следующих IP адресов"
	awk '{print $1}' access.log | sort | uniq -c | sort -nr | head
	echo
	echo
	echo "Список запрашиваемых URL (с наибольшим кол-вом запросов)"
	grep -Eo "(https?|ftp)://[a-zA-Z0-9./?=_:@~#%&;+$!*',-]+" access.log | sort | uniq -c | sort -nr | head
	echo
	echo
	echo "Ошибки веб-сервера/приложения c момента последнего запуска"
	#grep -Eo ' [4-5][0-5,9][0-5,9] [0-9]{3}' access.log | awk '{print $1}' | sort | uniq -c | sort -nr
	grep -Eo ' [4-5][0-5,9][0-5,9] [0-9]{3}' access.log | awk '{print $1}' | sort | uniq
	echo
	echo
	echo "Список всех кодов HTTP ответа с указанием их кол-ва"
	grep -Eo ' [1-5][0-5,9][0-9] [0-9]{1,} ' access.log | awk '{print $1}' | sort | uniq -c | sort -nr
}

#Проверка запущен ли в данный момент скрипт
if [ -n "$(ps aux | grep 'parslog.sh' | grep -v grep)" ]
then
	echo "Срипт parslog.sh уже запущен"
else
	parsing
fi
```



<b>p1.sh</b>  
```
#!/bin/bash

#Последнее записанное время
lasttime=''
#Строка для передачи в awk
stracs=''

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
}


#Файл для хранения последней даты обработки time_pars
#Если файла не существует или он пустой, тозаписываем в него время из первой строки access.log
if ! ([ -f "./time_pars" ] && [ -s "./time_pars" ]); then
    stracs="$(sed -n '1p' access.log)"
    echo "$stracs" | translate_date > ./time_pars
else
    #echo "Существует"
	time_start="$(sed -n '1p' time_pars)"
	let "time_end=$time_start+3600"

	#time_line=0
	time_line=$time_start
	while IFS= read -r stracs
	do		
		#Пока $time_line больше $time_start и меньше либо равно time_end
		if [ "$time_line" -ge "$time_start" ] && [ "$time_line" -lt "$time_end" ]; then
			echo $stracs
			time_line="$(echo "$stracs" | translate_date)"
		fi
		#cat access.log > access_test.log
		#read -r line
		#echo 
	done < access.log
fi
```

```
awk -F'[][]' '{print $2}' access.log | head
```
