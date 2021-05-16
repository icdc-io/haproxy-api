# Haproxy API

## Installation

You have to install HAProxy Nodes, before usage of haproxy_api.
See details: [Installation Guide](INSTALL.md)

## Usage
By default port ```3000``` is used.
Use header ```X-HaproxyApi-Key``` or ```key``` parameter to authorize requests:
```
X-HaproxyApi-Key: 37c2256c-35d6-4e57-a5aa-ef79329c99e8
```
```
http://host:3000/api/1/route?key=37c2256c-35d6-4e57-a5aa-ef79329c99e8
```

API key is stored in ```api_keys``` collection in database. See  [Installation Guide](INSTALL.md) to know how to add ```<here_is_api_key>```

Error processing:

 - Invalid data cause answer with HTTP code ```400```
 - On error manipulate HAProxy Nodes HTTP code ```500```


|HTTP|URL|Comment|JSON Answer|
|---|---|---|---|
|GET|```/api/1/routes```|Show routes|Array of routes|
|GET|```/api/1/routes?service=:id```|Show routes by service id|Array of routes|
|GET|```/api/1/routes?proto=:id```|Show routes by protocol name (http,https,tcp)|Array of routes|
|GET|```/api/1/routes/:id```|Get route by id|Single route|
|POST|```/api/1/routes```|Add new route|Added route|
|PUT|```/api/1/routes/:id```|Modify existing route|Modified route|
|PUT|```/api/1/routes/:id/suspend```|Suspend (disapprove) route|Modified route|
|PUT|```/api/1/routes/:id/set-path```|Adds backend option: http-request set-path $path|Modified route|
|DELETE|```/api/1/routes/:id```|Delete route|```204 No Content```|
|DELETE|```/api/1/routes```|Delete routes all routes|```204 No Content```|
|DELETE|```/api/1/routes?service=:id```|Delete routes by service id|```204 No Content```|
|POST|```/api/1/store```|Push configs to remote nodes|```200 OK```|
|GET|```/api/1/certs```|List certificates|All certificates|
|GET|```/api/1/certs/:id```|Get certificate by id|Single certificate|
|GET|```/api/1/certs?owner=:id```|Get certificates by username|List of certificates|
|GET|```/api/1/certs?domain=:id```|Get certificates by domain|List of certificates|
|POST|```/api/1/certs```|Add new SSL-certificate|Add certificate|
|PUT|```/api/1/certs/:id```|Update certificate (name)|```405 Not Implemented yet```|
|DELETE|```/api/1/certs/:id```|Delete certificate by id|```204 No Content```|
|GET|```/api/1/nodes```|List HAproxy nodes|All nodes|
|GET|```/api/1/nodes/:id```|Get HAproxy nodes by id|Single node|
|POST|```/api/1/nodes```|Add HAproxy node|Added nodes|
|DELETE|```/api/1/nodes```|Remove all HAproxy nodes|```204 No Content```|


### New route or Modify route
 - POST /api/1/route
 - PUT /api/1/route/:id

```json
{
 "name":"my balancer",
 "proto":"http",
 "host":"test1-vr.icdc.io",
 "service_id":"1000000075",
 "approve_status":"waiting",
 "backend":{
   "proto":"http",
   "balance":"roundrobin",
   "servers":[
     {
       "name":"vm1-id",
       "host":"172.20.140.22",
       "port":"8080"
     },
     {
       "name":"vm2-id",
       "host":"172.20.150.23",
       "port":"9000"
     }
   ]
 }
}
```

### List certificates by owner

 - GET /api/1/certs?owner=user@iba.by

```json
[
  {
    "created_at":"2018-02-21T15:01:18.687Z",
    "domains": ["danix1.icdc.io"],
    "id":"5a8d89be9f789d3d2e000001",
    "name":"ss cert 1",
    "not_after":"2019-02-20T08:01:49.000Z",
    "not_before":"2018-02-20T08:01:49.000Z",
    "owner":"dsatsura@gmail.com",
    "expired":false
  }
]
``` 

### List certificates by owner

 - GET /api/1/certs?owner=user@iba.by

```json
[
  {
    "created_at":"2018-02-21T15:01:18.687Z",
    "domains": ["danix1.icdc.io"],
    "id":"5a8d89be9f789d3d2e000001",
    "name":"ss cert 1",
    "not_after":"2019-02-20T08:01:49.000Z",
    "not_before":"2018-02-20T08:01:49.000Z",
    "owner":"dsatsura@gmail.com",
    "expired":false
  }
]
``` 
### Upload new certificate

 - POST /api/1/certs

```json
{
  "name":"cert1",
  "owner":"dsatsura@iba.by",
  "cert":"LS0tLS1CRUdJTiBDRVJUSU...<certificate pem content in base64>",
  "key":"LS0tLS1CRUdJTiBDRVJUSU...<certificate pem content in base64>",
  "ca":"LS0tLS1CRUdJTiBDRVJUSU...<certificate pem content in base64>"
}
```


## Internal implementation

### Добавление route

При поступлении запроса на добавление route:

-  Если указан параметр `host` и параметр `proto` соответствует HTTP/HTTPS/TCP (в противном случае генерируем ошибку):

    - Для протоколов HTTP/HTTPS добавляем  параметр `port` со значениями 80/443 соответственно
    -  Для TCP выделяются порты по очереди из диапазона 8000-9000: получаем список всех портов существующих TCP routes и к максимальному значению протокола прибавляем единицу. Если значение превышает 9000 - генерируем ошибку. Если получили пустой список портов - используем порт 8000.
- Вся информация заносится в коллекцию `routes`, если новый route не дублирует существующие (проверяется `proto`, `host`, `path`)

-  На основе новых данных (при условии, что параметр `approve_status` у route имеет значение `approved`) генерируется конфигурационный файл для Haproxy.

- Сгенерированный конфигурационный файл заливается на nodes из коллекции `haproxy_nodes`


### Пример конфигурации для HTTP

```
defaults router:http_begin

frontend router:https
  bind *:80
  mode http
  #option ?
  #WARN: no default_backend
  acl acl_00000000001 hdr(host) -i "test-vr.icdc.io"
  use_backend backend_00000000002 if acl_00000000001

backend backend_00000000002
  mode http
  option forwardfor
  server server_0000000011 172.20.234.73:8080 check

defaults router:http_end
```

### Пример конфигурации для HTTPS

```
defaults router:https_begin

frontend router:https
  bind *:443 ssl crt /etc/ssl/private/example.com.pem
  mode http
  reqadd X-Forwarded-Proto:\ https
  #option ?
  #WARN: no default_backend
  acl acl_00000000001 hdr(host) -i "test-vr.icdc.io"
  use_backend backend_00000000002 if acl_00000000001

backend backend_00000000002
  mode http
  option forwardfor
  server server_0000000011 172.20.234.73:443 check
defaults router:https_end
```

### Пример конфигурации для TCP

```
defaults router:tcp_begin


frontend router:tcp_0000000001
  bind *:8000
  mode tcp
  #option ?
  #WARN: no default_backend
  acl acl_0000000001 hdr(host) -i "test1-vr.icdc.io"
  use_backend backend_0000000011 if acl_0000000001

backend backend_0000000011
  mode tcp
  server server_0000000111 172.20.234.73:9999 check


frontend router:tcp_0000000002
  bind *:8001
  mode tcp
  #option ?
  #WARN: no default_backend
  use_backend backend_0000000022

backend backend_0000000022
  mode tc
  server server_0000000111 172.20.234.73:7777 check


defaults router:tcp_end
```

Все конфигурации проходят проверк командой `haproxy -f /etc/haproxy/router.cfg -c`
