# Vagrant-стенд с OSPF

Домашнее задание по курсу «Администратор Linux. Professional» (OTUS).

## Задание

1. Поднять три виртуалки.
2. Объединить их разными vlan:
   - поднять OSPF между машинами на базе Quagga (используется FRR — преемник Quagga);
   - изобразить асимметричный роутинг;
   - сделать один из линков «дорогим», но чтобы при этом роутинг был симметричным.

Формат сдачи: Vagrantfile + ansible.

## Структура репозитория

| Путь | Назначение |
|---|---|
| [Vagrantfile](Vagrantfile) | 3 ВМ (router1–3) на `ubuntu/focal64`, запуск Ansible |
| [ansible/](ansible) | Конфигурация Ansible |
| [ansible/provision.yml](ansible/provision.yml) | Плейбук: пакеты, FRR, sysctl, конфиги OSPF |
| [ansible/hosts](ansible/hosts) | Инвентарь, `router_id` для каждого хоста |
| [ansible/defaults/main.yml](ansible/defaults/main.yml) | Переменные `router_id_enable`, `symmetric_routing` |
| [ansible/templates/](ansible/templates) | Шаблоны `daemons` и `frr.conf.j2` |
| [ansible/requirements.yml](ansible/requirements.yml) | Коллекция `ansible.posix` (модуль `sysctl`) |
| [screenshots/](screenshots) | Скриншоты выполнения |

## Схема сети

```
                  192.168.10.0/24 (net1)
                          |
                     enp0s10 .1
                    [ router1 ]
          enp0s8 10.0.10.1    enp0s9 10.0.12.1
                /                     \
   r1-r2 10.0.10.0/30           r1-r3 10.0.12.0/30
              /                         \
   enp0s8 10.0.10.2                enp0s9 10.0.12.2
     [ router2 ]---- r2-r3 10.0.11.0/30 ----[ router3 ]
   enp0s9 10.0.11.2                enp0s8 10.0.11.1
     enp0s10 .1                       enp0s10 .1
          |                               |
  192.168.20.0/24 (net2)         192.168.30.0/24 (net3)

  Управление (host-only): router1 192.168.50.10, router2 .11, router3 .12 (enp0s16)
```

## Запуск

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install "ansible-core==2.17.*"
ansible-galaxy collection install -r ansible/requirements.yml
export ANSIBLE_CONFIG=$PWD/ansible/ansible.cfg
vagrant up
```

## Реализация

- OSPF поднят на FRR (Quagga не развивается с 2018 года), все линки в area 0.
- Один шаблон [frr.conf.j2](ansible/templates/frr.conf.j2) на все роутеры: адреса и сети берутся из фактов Ansible, адрес соседа на линке /30 вычисляется.
- `net.ipv4.conf.all.forwarding=1` — транзит пакетов, `net.ipv4.conf.all.rp_filter=0` — разрешение асимметричного роутинга.
- **Асимметричный роутинг** (`symmetric_routing: false`): у router1 `enp0s8` с `ip ospf cost 1000`. Трафик router1 → router2 идёт через router3, ответ router2 → router1 идёт напрямую.
- **Симметричный роутинг** (`symmetric_routing: true`): `ip ospf cost 1000` добавляется и на `enp0s8` router2. Линк r1-r2 «дорогой», трафик в обе стороны идёт через router3.

Переключение режимов без полного прогона плейбука:

```bash
sed -i 's/^symmetric_routing: .*/symmetric_routing: true/' ansible/defaults/main.yml
ansible-playbook -i ansible/hosts -l all ansible/provision.yml -t setup_ospf
```

## Проверка

```bash
vtysh -c "show ip ospf neighbor"
vtysh -c "show ip route ospf"
ping -I 192.168.10.1 192.168.20.1   # на router1
tcpdump -i enp0s9                   # на router2
tcpdump -i enp0s8                   # на router2
```

## Заметки

- Хост: Ubuntu 26.04, VirtualBox 7.2, Vagrant 2.4.9.
- В Vagrantfile используется `**ipconf`: Vagrant 2.4 работает на Ruby 3, который не передаёт хэш как именованные аргументы.
- Ansible 2.20 не поддерживает Python 3.8 на управляемых хостах (focal), поэтому используется ansible-core 2.17 в venv.
- В ВМ ставится FRR 10.x: метрики считаются от скорости интерфейса (10 вместо 100 из методички), на логику работы это не влияет.
