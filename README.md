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
#grep -Eo '[0-9]{3}\ [0-9]{3,5}' access.log | wc -l
```
