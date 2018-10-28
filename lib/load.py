import json
import sqlite3

def main():
    with open('catalog.json', 'r') as fin:
        courses = json.load(fin)

    db = sqlite3.connect('app.sqlite')
    cursor = db.cursor()
    with open('lib/schema.sql', 'r') as fin:
        cursor.executescript(fin.read())
    db.commit()

    for course in courses:
        cursor.execute(
            '''
            INSERT INTO course
                (dept, title, code, desc, deptnote, distnote, divattr,
                 dreqs, enrollmentpref, expected, limit_, matlfee, prerequisites,
                 rqmtseval, type, instr, extrainfo)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            (course['dept'],
             course['title'],
             course['code'],
             course['desc'],
             unlist(course['deptnote']),
             unlist(course['distnote']),
             unlist(course['divattr']),
             unlist(course['dreqs']),
             unlist(course['enrollmentpref']),
             course['expected'],
             course['limit'],
             unlist(course['matlfee']),
             unlist(course['prerequisites']),
             unlist(course['rqmtseval']),
             course['type'],
             unlist([instr for section in course['sections'] for instr in section['instr']]),
             unlist(course['extrainfo'])
            )
        )
        course_id = cursor.lastrowid
        for section in course['sections']:
            cursor.execute(
                """
                INSERT INTO section
                    (instr, tp, type, course_id)
                VALUES (?, ?, ?, ?)
                """,
                (unlist(section['instr']),
                 unlist(section['tp']),
                 section['type'],
                 course_id)
            )
    db.commit()


def unlist(l):
    return ';;'.join(l)

if __name__ == '__main__':
    main()