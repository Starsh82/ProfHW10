# ProfHW10
Написать скрипт на языке Bash для парсинга access.log
```
#!/bin/bash

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
```
