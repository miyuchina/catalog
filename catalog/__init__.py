import os
from flask import Flask
from catalog import api, db

app = Flask(__name__)
app.config.from_mapping(
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev'),
    DATABASE='app.sqlite'
)
app.register_blueprint(api.bp)
app.teardown_appcontext(db.close_db)

@app.route('/')
def index():
    return app.send_static_file('index.html')
