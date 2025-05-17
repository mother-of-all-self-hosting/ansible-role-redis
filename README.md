<!--
SPDX-FileCopyrightText: 2023 Slavi Pantaleev
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Redis Ansible role

> [!WARNING]
> **Starting from v7.4.x, Redis is no longer Open Source.**
>
> The Redis Labs company [announced their switch to source-available model](https://redis.com/blog/redis-adopts-dual-source-available-licensing/).
>
> However, we at [etke.cc](https://etke.cc) are interested in supporting the Open Source community, so although we will continue to maintain this role for a while, we recommend you to use [Valkey](https://valkey.io/) instead. You can find our Ansible role for it [here](https://github.com/mother-of-all-self-hosting/ansible-role-valkey).

This is an [Ansible](https://www.ansible.com/) role which installs [Redis](https://redis.io/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)
- (optional) [`com.devture.ansible.role.playbook_runtime_messages`](https://github.com/devture/com.devture.ansible.role.playbook_runtime_messages)

Check [defaults/main.yml](defaults/main.yml) for the full list of supported options.
