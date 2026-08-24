# Smart Relay

A web application for controlling relays (smart sockets and switches) via [Yandex Smart Home](https://yandex.ru/iot/).

## How it works

1. The user signs in via Yandex OAuth — obtains an access code on the Yandex website and enters it into the app
2. The app exchanges the code for a token and displays the list of relays from the account
3. Relays can be turned on and off directly from the interface

## Requirements

- Ruby 3.3.5
- Rails 8.0

## Setup

**1. Create an application in Yandex OAuth**

Go to [oauth.yandex.ru](https://oauth.yandex.ru), create an application, and request the `iot:view` and `iot:control` permissions.

**2. Fill in `.env`**

```
YANDEX_CLIENT_ID=...
YANDEX_CLIENT_SECRET=...
```

**3. Install dependencies and run**

```bash
bundle install
bin/dev
```

The application will be available at `http://localhost:3000`.

## Stack

- Ruby on Rails 8 — backend
- Tailwind CSS — styles
- Yandex Smart Home API — device control
- Yandex OAuth 2.0 — authentication
