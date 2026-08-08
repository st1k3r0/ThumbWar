# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ThumbWar is a Roblox game written in Luau, managed with [Rojo](https://rojo.space) (project sync) and [Rokit](https://github.com/rojo-rbx/rokit) (toolchain manager). This is currently a fresh Rojo template (placeholder "Hello world" scripts) — the game logic has not been built out yet.

## Toolchain

Tools are pinned in `rokit.toml`. Install them with:

```bash
rokit install
```

This provides `rojo` (7.7.0). Add new tools with `rokit add <tool>`.

## Common commands

```bash
# Build a place file from the project source
rojo build -o "ThumbWar.rbxlx"

# Start the sync server, then connect from the Rojo plugin in Roblox Studio
rojo serve
```

The typical dev loop: run `rojo serve`, open the place in Studio, connect via the Rojo Studio plugin, and edit `.luau` files on disk — changes sync live into Studio. There is no separate lint or test command configured.

## Architecture

`default.project.json` is the source of truth for how the filesystem maps into the Roblox DataModel. The three source trees under `src/` land in distinct runtime contexts:

- `src/shared` → `ReplicatedStorage.Shared` — modules accessible to both client and server (replicated to clients). Put shared logic and `require`-able ModuleScripts here.
- `src/server` → `ServerScriptService.Server` — server-only scripts; never replicated to clients.
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` — runs locally on each player.

Naming conventions determine the Roblox instance type Rojo generates:
- `init.server.luau` → a `Script` (server) at the folder's root
- `init.client.luau` → a `LocalScript` (client) at the folder's root
- `Name.luau` → a `ModuleScript` (e.g. `Hello.luau` returns a function)

`default.project.json` also declares baked-in scene/service state (Workspace baseplate, Lighting, SoundService with `RespectFilteringEnabled`). Edit these properties there rather than in Studio, since a `rojo build` regenerates them.

## Notes

- `ThumbWar.rbxlx`, `*.rbxl.lock`, and `sourcemap.json` are gitignored build/lock artifacts. The committed `place/ThumbWar.rbxl` is a binary place file.

## Project rules

ЗАПРЕЩЕНО выполнять команду `rojo build`. Она перезаписывает place-файл и уничтожает карту. Место сохраняется только вручную из Studio.

Весь код Luau пишется только в файлы в папке src обычными инструментами работы с файлами. MCP-сервер Roblox Studio использовать исключительно для объектов сцены: детали, модели, интерфейс, свойства. Никогда не создавать и не изменять исходники скриптов через MCP — Rojo их затрёт.

Все числовые настройки игры хранятся только в ReplicatedStorage/Shared/Config. В коде числовых литералов быть не должно.

Сервер никогда не доверяет клиенту. Клиент отправляет только намерение и метку времени. Все проверки, расчёты и решения об исходе выполняются на сервере.

Направления "влево" и "вправо" заданы в координатах экрана и одинаковы для обоих игроков. Камеру матча не зеркалить.

Сохранение данных игроков только через ProfileStore. DataStoreService напрямую не использовать.

Каждый вызов Connect должен иметь парный Disconnect при завершении матча. Утечки соединений недопустимы.

Весь интерфейс обязан быть работоспособным на телефоне: крупные кнопки, масштабируемые размеры.

Выполняй задачу строго по описанию. Ничего не добавляй от себя и не расширяй объём работы.

Для матчевой логики использовать только RemoteEvent. RemoteFunction допустим исключительно для запросов данных по инициативе клиента (магазин, лидерборды, профиль). Сервер никогда не вызывает RemoteFunction на клиенте.
Любое число, которое влияет на баланс или геймплей, живёт в Config. Шаблоны данных, сервисы и UI читают значения оттуда. В шаблоне профиля числовых литералов быть не должно.
Уточни правило про литералы в CLAUDE.md: в Config выносятся только балансовые значения — те, которые предполагается крутить при настройке игры. Пустое начальное состояние (нули счётчиков, Level 1, пустые таблицы) остаётся в шаблоне профиля как есть. Нули в Config не переносим.

Каждый новый серверный сервис регистрируется в списке запуска в init.server.luau и реализует метод Init. Клиентские контроллеры аналогично — через init.client.luau.

Перед тем как объявить задачу выполненной, проверь через MCP, что изменённый код реально присутствует в Studio, а не только на диске. Если его нет — сообщи, что Rojo отвалился, и не пытайся чинить логику.
