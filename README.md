# aws-wireguard

Два независимых split-туннеля WireGuard в аккаунте AWS `347288885877`. Клиенты подключаются по UDP/IPv4.

| Регион | Endpoint | Адреса внутри туннеля | Маршруты Mac |
|---|---|---|---|
| Франкфурт, `eu-central-1` | `63.188.144.22:51820` | `10.8.0.0/24`, `fd00:8::/64` | `vpn-routes.txt` |
| Virginia, `us-east-1` | `23.23.214.1:51820` | `10.9.0.0/24`, `fd00:9::/64` | `vpn-routes-virginia.txt` |

Исходящий IPv4 идёт через Internet Gateway, IPv6 — через egress-only Internet Gateway.

## Что изменилось 24 ноября 2026

В Virginia развёрнут отдельный VPN-сервер с собственным Elastic IP, парой ключей и Terraform state.
На Mac основным стал split-профиль Virginia. Профиль Франкфурта и его скрипты сохранены,
старые задания автозапуска и обновления маршрутов отключены. Профиль PayPal по-прежнему
выводит весь трафик через Франкфурт, а команда `vpn-normal` возвращает Mac на Virginia.

Список Virginia начался с маршрутов Франкфурта. В него отдельно добавлены
`217.72.199.68/32` для `www.mail.com` и `74.208.232.226/32` для формы на `signup.mail.com`.
При переключении оба сайта ответили по HTTPS через интерфейс Virginia, а контрольный
адрес вне списка пошёл через обычное подключение Mac.

## Где что лежит

- `infra/` — Terraform для Франкфурта в аккаунте `347288885877`, профиль `k8s-lab-admin`.
  State хранится в S3 по адресу `s3://k8s-lab-tfstate-347288885877/wireguard/terraform.tfstate`.
  Backend использует шифрование и S3 lockfile. Проект требует Terraform 1.11 или новее.
- `virginia/` — Terraform для Virginia. Обе конфигурации используют общие определения ресурсов
  через относительные символические ссылки. У каждого региона свои backend и зона.
  State Virginia — `wireguard/us-east-1/terraform.tfstate` в том же S3-бакете во Франкфурте.
- `vpn-routes.txt` — список сетей Франкфурта. Сохранённый скрипт этого профиля ссылается на файл в корне ветки `main`.
- `vpn-routes-virginia.txt` — список сетей основного профиля Mac. Для изменения маршрутов
  добавь или убери CIDR в этом файле и отправь изменение в `main`. Обновлятор читает
  [опубликованный список Virginia](https://raw.githubusercontent.com/jjjopa5/aws-wireguard/main/vpn-routes-virginia.txt).

Из корня репозитория конфигурацию можно проверить командой `terraform -chdir=infra validate`
после инициализации. На Mac с несколькими версиями Terraform проверь `terraform version`.

## Virginia на Mac

Основной split-профиль Mac — Virginia. Системный конфиг `/etc/wireguard/virginia.conf`
принадлежит root и имеет режим `0600`. При загрузке его поднимает LaunchDaemon
`com.wireguard.virginia`. Второй LaunchDaemon `com.vpn.update-routes-virginia`
в 12:00 и 23:00 по локальному времени читает `vpn-routes-virginia.txt` из ветки
`main` на GitHub. Оба пишут в `/var/log/wireguard-virginia.log`.

Обновлятор проверяет CIDR и меняет только AllowedIPs. При изменении списка активный
туннель перезапускается. Для выключенного профиля обновляется файл для следующего старта.
При HTTP-ошибке или невалидном списке текущий профиль сохраняется.

Управление из Bash на Mac:

```bash
wgq down virginia && wgq up virginia
sudo wg show
route -n get 217.72.199.68
sudo launchctl kickstart system/com.vpn.update-routes-virginia
```

Поле `interface` для www.mail.com должно совпасть с результатом
`sudo cat /var/run/wireguard/virginia.name`. В `sudo wg show` ожидается endpoint
`23.23.214.1:51820`. Для доступа к API Kubernetes-лабы через этот туннель проверь
разрешение `23.23.214.1/32` в firewall лабы.

Прежние задания `com.wireguard.wg0` и `com.vpn.update-routes` отключаются при установке.
Файлы plist, `wg0.conf` и `~/update-vpn-routes.sh` остаются на диске.

### Восстановление Virginia

Terraform создаёт ресурсы и ставит WireGuard через cloud-init. Для нового сервера и первого
пира скрипт `virginia/setup-server.sh` создаёт отдельную серверную пару ключей, настраивает
форвардинг и NAT для обеих семей адресов и включает `wg-quick@wg0`. Если нужно сохранить
идентичность уже работающего сервера, сначала восстанови его `/etc/wireguard` из защищённой копии.

На Mac команда `python3 virginia/mac-profile.py --public-key` выводит публичную часть ключа клиента.
После `cloud-init status --wait` на US-сервере передай её скрипту, например:

```bash
client_pub=$(python3 virginia/mac-profile.py --public-key)
ssh -i ~/.ssh/personal ubuntu@23.23.214.1 "sudo bash -s -- '$client_pub' 51820" < virginia/setup-server.sh
```

Скрипт выводит публичный ключ сервера. При первоначальной настройке Mac передай этот ключ
команде `python3 virginia/mac-profile.py --endpoint 23.23.214.1:51820 --server-key ПУБЛИЧНЫЙ_КЛЮЧ`.
Скрипт создаёт пользовательскую копию в `~/.config/wireguard/virginia/`.
Для первой установки или применения локального списка до публикации выполни из корня проекта:

```bash
python3 virginia/mac-profile.py
sudo /bin/bash virginia/macos/install.sh "$HOME/.config/wireguard/virginia/virginia.conf"
```

В обычном режиме обновлением системной копии занимается launchd.

## Состояние WireGuard во Франкфурте

Terraform устанавливает WireGuard, qrencode и включает форвардинг IPv4/IPv6. Конфигурация
`wg0.conf` и ключи хранятся отдельно в `/etc/wireguard`. Для восстановления на пустой
машине с доступного сервера можно передать каталог по SSH. Укажи SSH-ключи для обоих
хостов через SSH config или параметр `-i`, затем выполни:

```bash
ssh ubuntu@ИСТОЧНИК 'sudo tar czf - -C /etc wireguard' \
  | ssh ubuntu@ПРИЁМНИК 'sudo tar xzf - -C /etc'
```

Проверить, что интерфейс наружу называется `ens5` — он захардкожен в `PostUp`/`PostDown`
внутри `wg0.conf`. Сверить имя с выводом `ip route show default`, затем на принимающей машине запустить
`sudo systemctl enable --now wg-quick@wg0`.

## Клиенты Франкфурта

- **Mac** — конфиг перегенерирует `~/update-vpn-routes.sh` (Endpoint и ключ сервера
  зашиты в нём). Скрипт выходит молча, если `vpn-routes.txt` не менялся, поэтому после
  правки Endpoint нужно сначала снести кеш: `rm /tmp/vpn-routes.cache`.
  Сам конфиг лежит в `/etc/wireguard/wg0.conf` (не в `/opt/homebrew/etc/wireguard`).
  До перехода на Virginia туннель поднимал при загрузке LaunchDaemon `com.wireguard.wg0` (`RunAtLoad`, без
  `KeepAlive`), а LaunchAgent `com.vpn.update-routes` запускал скрипт в 12:00 и 23:00.
- **iPhone / iPad владельца** — приватных ключей на сервере нет, Endpoint правится
  руками в приложении.
- **Остальные пиры** (Shpakovskiy Maxim ×2, Danik, Anton ×2) — при смене Endpoint обновить его на каждом устройстве.
  Приватные ключи Danik, Anton и телефона Максима лежат на сервере в `/etc/wireguard`,
  так что при необходимости их конфиги можно пересобрать и отдать QR через `qrencode`.
- **Alesya** (телефон `10.8.0.10`, мак `10.8.0.11`) — добавлена 14.10.2026. Приватные
  ключи на сервере: `/etc/wireguard/alesya-phone.key` и `alesya-mac.key`.
- **Nastya** (телефон `10.8.0.12`, компьютер `10.8.0.13`) — добавлена 12.11.2026.
  Приватные ключи на сервере: `/etc/wireguard/nastya-phone.key` и `nastya-pc.key`.
  В её конфиг попали все маршруты из `vpn-routes.txt`, включая API k8s-лаба.

## PayPal: весь трафик через Франкфурт

PayPal целиком сидит на CDN (Fastly `151.101.0.0/16` и Cloudflare), а его собственные
сети из `AS17012` сайтом не используются. Завернуть его в split-туннель надёжно нельзя:
адреса CDN плавают, а при промахе запрос молча уходит напрямую, и антифрод видит одну
сессию из двух стран. Поэтому для PayPal отдельные профили с `AllowedIPs = 0.0.0.0/0, ::/0`,
которые включаются только на время работы с ним.

- **iPhone владельца** — пир `10.8.0.14`, профиль `PayPal` в приложении WireGuard.
  Ключ на сервере: `/etc/wireguard/owner-iphone-paypal.key`.
- **Mac владельца** — пир `10.8.0.15`, конфиг `/etc/wireguard/paypal.conf` рядом с `wg0.conf`.
  Ключ на сервере: `/etc/wireguard/owner-mac-paypal.key`.

На маке переключение — функциями из `~/.bash_profile`:

```bash
vpn-paypal   # выключить Virginia и поднять PayPal-профиль
curl -s https://ifconfig.me; echo   # в режиме PayPal ожидается 63.188.144.22
vpn-normal   # выключить PayPal и вернуть Virginia
```

После загрузки основной split-профиль — Virginia. При выключенной Virginia обновлятор
может обновить её файл на диске, сохранив активное соединение PayPal.

## Доступ на сервер во Франкфурте

`aws_key_pair` в терраформе кладёт один ключ — владельца. Второй ключ (Максим)
добавлен вручную в
`/home/ubuntu/.ssh/authorized_keys` и в терраформе не описан: репозиторий публичный,
чужие ключи и почты в него класть незачем.

Из этого следует: **при пересоздании инстанса второй ключ пропадёт** — забрать его
со старой машины или попросить прислать заново.

И помнить, что `ubuntu` ходит под passwordless sudo, то есть любой, у кого есть ssh
на эту машину, читает `/etc/wireguard` целиком — включая приватные ключи всех пиров.
