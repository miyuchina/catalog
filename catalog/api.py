from flask import Blueprint, jsonify
from catalog.db import get_db

bp = Blueprint('api', __name__, url_prefix='/api')

@bp.route('/courses')
def courses():
    cursor = get_db().cursor()
    cursor.execute('SELECT * FROM course ORDER BY dept, code')
    return jsonify(cursor.fetchall())

@bp.route('/course/<int:course_id>')
def course(course_id):
    cursor = get_db().cursor()
    cursor.execute('SELECT * FROM section WHERE course_id = ?', (course_id,))
    return jsonify(cursor.fetchone())
