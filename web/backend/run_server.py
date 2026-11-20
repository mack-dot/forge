#!/usr/bin/env python3
"""Start the Discovery One backend on 127.0.0.1 only (port: FORGE_WEB_PORT, default 8787).

  cd web/backend && .venv/bin/python run_server.py     (any venv made from requirements.lock; .venv/ is untracked)

The bind address is fixed in code on purpose: nothing here is ready for a public port (web/README.md).
"""

import sys

import uvicorn

from app.config import Settings, SettingsError
from app.main import create_app


def main():
    try:
        s = Settings.from_env()
    except SettingsError as e:
        print('settings error: %s' % e, file=sys.stderr)
        return 2
    app = create_app(s)
    uvicorn.run(app, host='127.0.0.1', port=s.port, server_header=False, date_header=False, access_log=False,
                proxy_headers=False, timeout_keep_alive=5, limit_concurrency=200, h11_max_incomplete_event_size=16384,
                log_level='warning')
    return 0


if __name__ == '__main__':
    sys.exit(main())
