from flask import Blueprint, jsonify, request, session
from werkzeug.security import check_password_hash, generate_password_hash
from catalog.db import get_db

bp = Blueprint('api', __name__, url_prefix='/api')


@bp.route('/courses')
def courses():
    cursor = get_db().cursor()
    cursor.execute('SELECT id, dept, code, title, instr FROM course ORDER BY dept, code')
    return jsonify(cursor.fetchall())


@bp.route('/course/<int:course_id>')
def course(course_id):
    cursor = get_db().cursor()
    cursor.execute(
        """
        SELECT
            id, desc, deptnote, distnote, divattr, dreqs, enrollmentpref, expected,
            limit_, matlfee, prerequisites, rqmtseval, extrainfo, type
        FROM course WHERE id = ?
        """,
        (course_id,)
    )
    course = cursor.fetchone()
    cursor.execute('SELECT * FROM section WHERE course_id = ?', (course_id,))
    course['section'] = cursor.fetchall()
    return jsonify(course)


@bp.route('/user/login', methods=('GET', 'POST'))
def login():
    if request.method == 'POST':
        data = request.get_json() or {}
        username = data.get('username', None)
        password = data.get('password', None)
        if not username or not password:
            return fail('Invalid request.')

        user = get_db().cursor().execute(
            'SELECT * FROM user WHERE username = ?', (username,)
        ).fetchone()

        if user is None:
            return fail('Empty username.')

        if not check_password_hash(user['password'], password):
            return fail('Wrong password.')

        session.clear()
        session['user_id'] = user['id']
        return success(f'User {username} logged in.')

    return 'user_id' in session


@bp.route('/user/register', methods=('POST',))
def register():
    data = request.get_json() or {}
    username = data.get('username', None)
    password = data.get('password', None)
    if not username or not password:
        return fail('Invalid request.')

    if db.execute(
        'SELECT id FROM user WHERE username = ?', (username,)
    ).fetchone() is not None:
        return fail(f'User {username} is already registered.')

    db.execute(
        'INSERT INTO user (username, password) VALUES (?, ?)',
        (username, generate_password_hash(password),)
    )
    db.commit()
    return success(f'User {username} registered.')


@bp.route('/user/logout', methods=('POST',))
def logout():
    session.clear()
    return success('You are logged out.')


def success(msg):
    return jsonify({'success': True, 'msg': msg})


def fail(msg):
    return jsonify({'success': False, 'msg': msg})
