import sqlite3
from flask import current_app, g

def get_db():
    if 'db' not in g:
        g.db = sqlite3.connect(
            current_app.config['DATABASE'],
            detect_types=sqlite3.PARSE_DECLTYPES
        )
        g.db.row_factory = lambda c, r: dict(zip([col[0] for col in c.description], r))
    return g.db

def close_db(e=None):
    db = g.pop('db', None)

    if db is not None:
        db.close()
