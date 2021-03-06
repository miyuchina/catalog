DROP TABLE IF EXISTS user;
DROP TABLE IF EXISTS bucket;
DROP TABLE IF EXISTS course;
DROP TABLE IF EXISTS section;

CREATE TABLE user (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT UNIQUE NOT NULL
);

CREATE TABLE bucket (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT UNIQUE NOT NULL,
    courses TEXT,
    user_id INTEGER NOT NULL
);

CREATE TABLE course (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    dept           TEXT,
    title          TEXT,
    code           INTEGER,
    passfail       INTEGER,
    fifthcourse    INTEGER,
    desc           TEXT,
    deptnote       TEXT,
    xlistings      TEXT,
    wsnotes        TEXT,
    dpenotes       TEXT,
    qfrnotes       TEXT,
    divattr        TEXT,
    dreqs          TEXT,
    enrollmentpref TEXT,
    expected       TEXT,
    limit_         TEXT,
    matlfee        TEXT,
    prerequisites  TEXT,
    rqmtseval      TEXT,
    extrainfo      TEXT,
    type           TEXT,
    instr          TEXT,
    term           TEXT
);

CREATE TABLE section (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    instr TEXT,
    tp    TEXT,
    type  TEXT,
    nbr   INTEGER,
    course_id INTEGER NOT NULL
);
