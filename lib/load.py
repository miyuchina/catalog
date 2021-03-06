import json
import sqlite3

def main():
    with open('catalog.json', 'r') as fin:
        courses = json.load(fin)

    db = sqlite3.connect('app.sqlite')
    cursor = db.cursor()
    #with open('lib/schema.sql', 'r') as fin:
    #    cursor.executescript(fin.read())
    #db.commit()

    for course in courses:
        cursor.execute(
            '''
            INSERT OR REPLACE INTO course
                (id, dept, title, code, passfail, fifthcourse, desc, deptnote,
                 xlistings, wsnotes, dpenotes, qfrnotes, divattr, dreqs,
                 enrollmentpref, expected, limit_, matlfee, prerequisites,
                 rqmtseval, type, instr, extrainfo, term)
            VALUES (
                (SELECT id FROM course WHERE dept = ? AND code = ?),
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            ''',
            (course['dept'],
             course['code'],
             course['dept'],
             course['title'],
             course['code'],
             course['passfail'],
             course['fifthcourse'],
             course['desc'],
             unlist(course['deptnote']),
             unlist(course['xlistings']),
             course['wsnotes'],
             course['dpenotes'],
             course['qfrnotes'],
             unlist(course['divattr']),
             unlist(course['dreqs']),
             unlist(course['enrollmentpref']),
             course['expected'],
             course['limit'],
             unlist(course['matlfee']),
             unlist(course['prerequisites']),
             unlist(course['rqmtseval']),
             course['type'],
             unlist(set([instr for section in course['sections'] for instr in section['instr']])),
             unlist(course['extrainfo']),
             course['term']
            )
        )
        course_id = cursor.lastrowid
        for section in course['sections']:
            cursor.execute(
                """
                INSERT OR REPLACE INTO section
                    (id, instr, tp, type, nbr, course_id)
                VALUES (
                    (SELECT id FROM section WHERE nbr = ?),
                    ?, ?, ?, ?, ?
                )
                """,
                (section['nbr'],
                 unlist(section['instr']),
                 unlist(section['tp']),
                 section['type'],
                 section['nbr'],
                 course_id)
            )
    db.commit()


def unlist(l):
    return ';;'.join(l)

if __name__ == '__main__':
    main()
