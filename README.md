# ProfHW10
Написать скрипт на языке Bash для парсинга access.log
В связи с тем, что это учебная задача, то парсинг лога в разрезе времени пришлось сделать не очень логично.
Для реальной задачи надо было бы получать текущее время и делать выборку из лога за последний прошедший час, но в условиях наличия статического лога сделанного за прошлый период времени, пришлось изменить логику работы скрипта. Скрипт начинает выводить статитстику начиная с первой записи в логе отсчитывая 1 час вперёд, "запоминая" поледнее время. При каждом запуске он парсит лог начиная со времени окончания предыдущей группы строк из лога (не знаю как написать более понятно). В общем коряво, нелогично, бесполезно, но подругому я не придумал. :)
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

#Проверка запущен ли в данный момент скрипт
if [ -n "$(ps aux | grep 'parslog.sh' | grep -v grep)" ]
then
	echo "Срипт уже parslog.sh запущен"
else
	

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
fi

awk -F'[][]' '{print $2}' access.log | head


```

Содержимое тестового файла p1.sh  
```
#!/bin/bash

#Последнее записанное время
lasttime=''
#Строка для передачи в awk
stracs=''

#Преобразование даты в секунды
#echo "14/Aug/2019:04:12:10" | sed 's/:/ /' | awk -F'[/ ]' '
translate_date () {
    awk -v str="$stract" -F'[][]' '{print $2}' | awk '{print $1}' | sed 's/:/ /' | awk -F'[/ ]' '
    {
        # Создаем массив с номерами месяцев
        months["Jan"] = "01"; months["Feb"] = "02"; months["Mar"] = "03";
        months["Apr"] = "04"; months["May"] = "05"; months["Jun"] = "06";
        months["Jul"] = "07"; months["Aug"] = "08"; months["Sep"] = "09";
        months["Oct"] = "10"; months["Nov"] = "11"; months["Dec"] = "12";
        
        printf "%s-%s-%s %s\n", $3, months[$2], $1, $4
    }' | xargs -I {} date -d "{}" +%s
}


#Файл для хранения последней даты обработки
if ! ([ -f "./time_pars" ] && [ -s "./time_pars" ]); then
    stracs="$(sed -n '1p' access.log)"
    echo "$stracs" | translate_date
else
    echo "Существует"
fi
```

```
awk -F'[][]' '{print $2}' access.log | head
```
