# Keenetic Dnsmasq Routing

## Замечания

- Этот код создан для изучения сетевых технологий. Он может быть полезен для улучшения работы интернета, но то, как вы его используете — ваш выбор.
  Автор ответственности не несет.

- Статическая маршрутизация на основе dnsmasq требует времени для сбора IP-адресов доменов.
  В начале возможна нестабильность — просто обновите страницу пару раз что бы собрались возможные IP-адреса домена.

## Требования

- [Keenetic OS](https://help.keenetic.com/hc/ru/articles/115000990005) версии 4.0 или выше.
- Установленный [Entware](https://help.keenetic.com/hc/ru/articles/360021214160).

## Шаги установки

### 1. Первичные настройки в веб-панели Keenetic

- Купите, настройте и включите туннель [VPN](https://help.keenetic.com/hc/ru/articles/115005342025)
  или [Proxy](https://help.keenetic.com/hc/ru/articles/7474374790300).

### 2. Установка необходимых компонентов

- Выполните следующую команду:

  ```sh
  opkg update && opkg install curl && sh -c "$(curl -H 'Cache-Control: no-cache' -f -L https://raw.githubusercontent.com/GuFFy12/keenetic-dnsmasq-routing/refs/heads/main/install.sh)"
  ```

- Или если хотите установить в режиме оффлайн, то разархивируйте на роутере
  [файл релиз](https://github.com/GuFFy12/keenetic-dnsmasq-routing/releases/latest) и запустите:

  ```sh
  sh install.sh
  ```

### 3. Продолжение настройки в веб-панели Keenetic

- Отключите [DNS от провайдера](https://help.keenetic.com/hc/ru/articles/360008609399) (опционально, но желательно).
- Создайте записи DNS на адресе `192.168.1.1:5300` для доменов, к которым нужен доступ через туннель.
- Пример списка доменов:

  ```plaintext
  chatgpt.com
  openai.com
  oaiusercontent.com
  github.com
  githubusercontent.com
  githubcopilot.com
  ```

### 5. Конфигурация Dnsmasq ([`/opt/dnsmasq_routing/dnsmasq.conf`](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html))

- Переменная `server` установлена автоматически на первый найденный `127.0.0.1:port`, который используется для получения DNS записей.
  Чтобы вручную получить список DNS серверов, выполните команду:

  ```sh
  cat /tmp/ndnproxymain.stat
  ```

### 6. Конфигурация Dnsmasq Routing (`/opt/dnsmasq_routing/dnsmasq_routing.conf`)

- Устройство отправляет DNS-запрос на маршрутизатор, который с помощью dnsmasq возвращает IP-адрес и добавляет его в ipset.
  Все IP-адреса из ipset перенаправляются через туннель. Для работы системы важно, чтобы все DNS-запросы шли через маршрутизатор.
- Переменные `INTERFACE` и `INTERFACE_SUBNET` установлены в зависимости от вашего выбора во время установки.
  Чтобы вручную получить список интерфейсов выполните команду:

  ```sh
  ip -o -4 addr show
  ```

- Опционально настройте следующие переменные:
  - `KILL_SWITCH` - если установлено в `1`, при отключении VPN или прокси трафик не будет направляться в сеть.
  - `IPSET_TABLE_SAVE` - если установлено в `1`, таблица с IP-адресами будет сохранена при перезагрузке.
  - `IPSET_TABLE` - имя таблицы ipset.
  - `IPSET_TABLE_TIMEOUT` - тайм-аут для записей в таблице (`0` для неограниченного времени).
  - `INTERFACE` - интерфейс выходного узла туннеля.
  - `INTERFACE_SUBNET` - подсеть интерфейса выходного узла туннеля.
  - `MARK` - маркер, используемый в iptables.
