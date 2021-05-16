# Haproxy API

## Установка:

Скачайте rvm, добавьте путь к rvm в PATH и установите нужную версию ruby (>2.2.2), установите ее по умолчанию в системе :
```bash
$ curl -L get.rvm.io | bash -s stable
$ vim /root/.bash_profile
PATH=$PATH:/usr/local/rvm/bin
export PATH
$ . /root/.bash_profile
$ rvm install 2.3.1
$ /bin/bash --login
$ rvm use 2.3.1 --default
$ ruby -v
ruby 2.3.1p112 (2016-04-26 revision 54768) [x86_64-linux]
```
Устанавливаем bundler:
```bash
$ gem install bundler
$ bundle install
```
Устанавливаем MongoDB: https://docs.mongodb.com/manual/tutorial/install-mongodb-on-red-hat/

Запускам MongoDB сервис:
```bash
$ systemctl enable mongod
$ systemctl start mongod
```
Устанавливаем через setup-скрипт для CentOS 7.x:
- Создает пользователя haproxyapi
- Открывает с помощью firewall-cmd порт 3000/tcp
- Устанавливает systemd unit file: haproxy-api.service

```bash
$ scripts/setup
$ systemctl start haproxy-api.service
```

## Настройка HAProxy Node

Сгенерируйте ключи для пользователя haproxyapi.
```bash
$ su - haproxyapi
$ ssh-keygen
$ ssh-copy-id root@haproxy-node1
$ ssh-copy-id root@haproxy-node2
```
Проверьте скорость доступа по SSH и время выполнения операций нодах. Это критично влияет на общее время API-запросов POST/DELETE:

Плохое времени выполнения операций > 1сек :
```
[root@haproxy-api haproxy_api]# time ssh root@172.20.231.55 exit
real    0m5.405s
user    0m0.014s
sys 0m0.007s
```
> Проблема с длительными операциями, чаще всего в неправильно настроенном резолве PTR-записей haproxy_api хоста.
>
> **Workaround:** Добавьте IP-адрес haproxy_api в /etc/hosts на каждой ноде, чтобы исключить запросы к DNS.

Хорошее время выполнения операций < 1сек :
```
[root@haproxy-api haproxy_api]# time ssh root@172.20.231.55 exit
real    0m0.451s
user    0m0.011s
sys 0m0.013s
```

Добавьте на каждую ноду запись в переменную ```OPTIONS```:
```bash
$ vim /etc/sysconfig/haproxy
OPTIONS="-f /etc/haproxy/router.cfg"
```

## Создание и инициализация базы данных

### Создание БД и коллекций

```bash
$ mongo
> use haproxy_api_dev
> db.createCollection("api_keys")
> db.createCollection("haproxy_nodes")
> db.createCollection("routes")
```

### Добавление HAProxy Node

```bash
> db.haproxy_nodes.insert({"name" : "haproxy1", "host" : "<haproxy-node1_IP>", "port" : 22, "user" : "root"})
> db.haproxy_nodes.insert({"name" : "haproxy2", "host" : "<haproxy-node2_IP>", "port" : 22, "user" : "root"})
```

### Добавление AUTH key

```bash
mongo haproxy_api_dev --quiet --eval "db.api_keys.insert({'value':'"`uuidgen`"'})"
mongo haproxy_api_dev --quiet --eval "db.api_keys.find()"
```
