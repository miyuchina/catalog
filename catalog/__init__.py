import os
from flask import Flask, render_template
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
    return render_template('courses.html')
