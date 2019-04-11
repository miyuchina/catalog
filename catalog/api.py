from flask import Blueprint, jsonify, request, session
from werkzeug.security import check_password_hash, generate_password_hash
from catalog.db import get_db

bp = Blueprint('api', __name__, url_prefix='/api')


@bp.route('/courses/<term>')
def courses(term):
    cursor = get_db().cursor()
    cursor.execute(
        'SELECT id, dept, code, title, instr FROM course WHERE term = ? ORDER BY dept, code',
        (term,)
    )
    return jsonify(cursor.fetchall())


@bp.route('/course/<int:course_id>')
def course(course_id):
    cursor = get_db().cursor()
    cursor.execute(
        """
        SELECT
            id, desc, passfail, fifthcourse, deptnote, distnote, divattr, dreqs,
            enrollmentpref, expected, limit_, matlfee, prerequisites, rqmtseval,
            extrainfo, type
        FROM course WHERE id = ?
        """,
        (course_id,)
    )
    course = cursor.fetchone()
    cursor.execute('SELECT * FROM section WHERE course_id = ?', (course_id,))
    course['section'] = cursor.fetchall()
    course['passfail'] = bool(course['passfail'])
    course['fifthcourse'] = bool(course['fifthcourse'])
    return jsonify(course)


@bp.route('/user/login', methods=('GET', 'POST'))
def login():
    if request.method == 'POST':
        data = request.get_json() or {}
        username = data.get('username', None)
        password = data.get('password', None)
        if not username or not password:
            return fail('Empty username or password.')

        user = get_db().cursor().execute(
            'SELECT * FROM user WHERE username = ?', (username,)
        ).fetchone()

        if user is None:
            return fail('No such user.')

        if not check_password_hash(user['password'], password):
            return fail('Wrong password.')

        session.clear()
        session['user_id'] = user['id']
        return success(f'User {username} logged in.')

    user_id = session.get('user_id', None)
    if user_id:
        user = get_db().cursor().execute(
            'SELECT username FROM user WHERE id = ?', (user_id,)
        ).fetchone()
        return jsonify((user or {}).get('username', None))
    return jsonify(None)


@bp.route('/user/register', methods=('POST',))
def register():
    data = request.get_json() or {}
    username = data.get('username', None)
    password = data.get('password', None)
    if not username or not password:
        return fail('Empty username or password.')

    db = get_db()

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


@bp.route('/bucket/<name>', methods=('GET', 'POST'))
def bucket(name):
    empty_bucket = {"id": 0, "name": "", "courses": ""}
    if request.method == 'POST':
        data = (request.get_json() or {})
        courses = data.get('courses', None)
        if not courses:
            return fail("That's an empty bucket!", **empty_bucket)

        db = get_db()
        cursor = db.cursor()
        user_id = session.get('user_id', None)
        if not user_id:
            return fail("You are not logged in!", **empty_bucket)

        user = cursor.execute(
            'SELECT user_id FROM bucket WHERE name = ?', (name,)
        ).fetchone()

        if user is not None and user['user_id'] != user_id:
            return fail("You don't have permission to save to this bucket!", bucket_id=0)

        cursor.execute(
            """
            INSERT OR REPLACE INTO bucket (name, courses, user_id) VALUES (?, ?, ?)
            """,
            (name, courses, user_id)
        )
        bucket_id = cursor.lastrowid
        db.commit()
        return success(
            f"Saved to bucket {name}!",
            **{"id": bucket_id, "name": name, "courses": courses}
        )

    bucket = get_db().execute(
        'SELECT id, name, courses FROM bucket WHERE name = ?', (name,)
    ).fetchone()
    if bucket is None:
        return fail("No such bucket!", **empty_bucket)
    return success(f"Loaded bucket {name}!", **bucket)


@bp.route('/user/buckets')
def buckets():
    user_id = session.get('user_id', None)
    if not user_id:
        return fail("You are not logged in!", names=[])
    buckets = get_db().execute(
        """
        SELECT name FROM bucket WHERE user_id = ?
        """,
        (user_id,)
    ).fetchall()
    return success('Here are your buckets!', names=[bucket['name'] for bucket in buckets])



def success(msg, **kwargs):
    return jsonify({'success': True, 'msg': msg, **kwargs})


def fail(msg, **kwargs):
    return jsonify({'success': False, 'msg': msg, **kwargs})
