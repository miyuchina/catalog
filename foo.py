import json
from pprint import pprint

with open('catalog.json', 'r') as fin:
    courses = json.load(fin)

times = sorted(list(set([tp for course in courses for section in course['sections'] for tp in section['tp']])))


def parse_time(time):
    if time == 'TBA':
        return None
    days, time = time.split(maxsplit=1)
    days = list(days)
    start_time, end_time = map(to_24h, time.split(' - '))
    return days, start_time, end_time

def to_24h(time):
    hhmm, ampm = time.split(' ', maxsplit=1)
    hour, minute = map(int, hhmm.split(':', maxsplit=1))
    if ampm == 'am' or hour == 12:
        return hour, minute
    return int(hour) + 12, minute
