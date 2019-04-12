import json
import inspect
import asyncio
import requests
import requests_cache
from bs4 import BeautifulSoup as Soup


requests_cache.install_cache()


async def find_courses(term, soup):
    courses = []
    seen = set()
    tags = soup.select('.catalog_table li')[1:]
    total = len(tags)
    for i, tag in enumerate(tags, start=1):
        url = tag.div.a['href']
        course = await find_course(url)
        if course is not None:
            if f"{course['dept']}{course['code']}" not in seen:
                course['term'] = term
                courses.append(course)
                seen.add(f"{course['dept']}{course['code']}")
            print(f'[{i} / {total}] {course["dept"]} {course["code"]} - {course["title"]}')
    return courses


async def find_course(url):
    res = await asyncio.get_event_loop().run_in_executor(None, requests.get, url)
    soup = Soup(res.text, 'html.parser')
    c_dept, c_code, c_title, c_dreqs = await parse_header(soup.select('.title-bar h1')[0])
    c_desc = await parse_desc(soup.select('div.catalogdesc')[0])
    specifics = await parse_specifics(soup.select('div.specifics')[0])
    locals().update({f'c_{k}': v for k, v in specifics.items()})
    try:
        c_sections = await parse_sections(soup.select('.Rtable-cell.classes')[1:],
                                          soup.select('.Rtable-cell.instructors')[1:],
                                          soup.select('.Rtable-cell.times')[1:],
                                          soup.select('.Rtable-cell.Nbr')[1:])
    except AttributeError:
        return None
    return make_course()


async def parse_header(tag):
    def textify(s):
        try:
            return s.text
        except:
            return str(s)

    dept = tag.a.extract().text.strip()
    code = int(next(tag.children).next_sibling.extract())

    dreqs = []
    for item in tag.span.extract().select('span'):
        try:
            item['class'].remove('dreq')
            dreqs.append(parse_dreq(*item['class']))
        except ValueError:  # no dreq class, not dreq
            pass

    title = ''.join(textify(c) for c in list(tag.children)).strip()
    return dept, code, title, dreqs


async def parse_desc(tag):
    return tag.text.strip()


async def parse_specifics(tag):
    specifics = {'divattr':        [],
                 'matlfee':        [],
                 'enrollmentpref': [],
                 'deptnote':       [],
                 'prerequisites':  [],
                 'extrainfo':      [],
                 'rqmtseval':      [],
                 'type':           '',
                 'limit':          '',
                 'expected':       '',
                 'xlistings':      [],
                 'wsnotes':        '',
                 'dpenotes':       '',
                 'qfrnotes':       '',
                 'fifthcourse':    False,
                 'passfail':       False,
                }
    for entry in tag.select('div'):
        result = await parse_label_value(entry)
        for name, value in result.items():
            if name not in specifics:
                raise KeyError(f'Missing specifics entry: {name}')
            if isinstance(value, list):
                specifics[name].extend(value)
            else:
                specifics[name] = value
    return specifics


async def parse_label_value(entry):
    name = entry['class'][0]
    label = entry.select('span.label')[0].text.strip().replace(':', '')
    if label == 'Distributions':
        return {}
    value = entry.select('span.value')[0].text.strip()
    if name == 'classformat':
        return parse_class_format(value)
    if name == 'distnote':
        return parse_dist_note(label, value)
    value = [item.strip() for item in value.split(';')]
    return {name: value}


async def parse_sections(class_tags, instructor_tags, time_tags, nbr_tags):
    sections = []
    for class_tag, instructor_tag, time_tag, nbr_tag in zip(class_tags, instructor_tags, time_tags, nbr_tags):
        s_type = (list(class_tag.children)[-1].strip().split(maxsplit=1) or [''])[0]
        s_instr = list(filter(None, [parse_instr(child) for child in instructor_tag.span.children]))
        s_tp = [el.replace('<br/>', '').strip()
                for el in time_tag.span.decode_contents().strip().split('<hr/>')]
        s_nbr = int(nbr_tag.text.strip())
        sections.append({'type': s_type, 'instr': s_instr, 'tp': s_tp, 'nbr': s_nbr})
    return sections


def parse_instr(span):
    try:
        return span.strip()
    except:
        return span.text.strip()


def parse_class_format(value):
    result = {}
    for pair in value.split('  '):
        k, v = pair.split(':', maxsplit=1)
        if k == 'Class#':
            continue
        elif k == 'Grading':
            fifth_course = False
            pass_fail = False
            for line in v.strip().splitlines():
                if line.endswith('pass/fail option,'):
                    pass_fail = line.startswith('yes')
                elif line.endswith('fifth course option'):
                    fifth_course = line.startswith('yes')
            result['fifthcourse'] = fifth_course
            result['passfail'] = pass_fail
        else:
            result[k.lower().strip()] = v.strip()
    return result


def parse_dist_note(label, value):
    if label == 'Notes':
        value = [f'{c}: {d}' for c, d in zip(*[value.splitlines()[3+i::2] for i in range(2)])]
        return {'xlistings': value}
    return {label.replace(' ', '').lower(): value}


def parse_dreq(dreq):
    return {'div_d2' : 'Divison II',
            'qfr_qfr': 'Quantative Formal Reasoning',
            'div_d3' : 'Division III',
            'div_d1' : 'Division I',
            'dpe_dpe': 'Difference, Power and Equity',
            'wac_wac': 'Writing Skills'}[dreq.lower()]


def make_course():
    return {k[2:]: v for k, v in inspect.stack()[1].frame.f_locals.items() if k.startswith('c_')}


async def main():
    fall_term = 1201
    spring_term = 1203

    URI = "https://catalog.williams.edu/list/?kywd=&Action=Search&strm={}&subj=&sbattr=&cn=&enrlmt=&cmp=&sttm=&endtm=&insfn=&insln="

    soup = Soup(requests.get(URI.format(fall_term)).text, 'html.parser')
    fall_courses = await find_courses("fall-2019", soup)

    soup = Soup(requests.get(URI.format(spring_term)).text, 'html.parser')
    spring_courses = await find_courses("fall-2019", soup)

    courses = []
    courses.extend(fall_courses)
    courses.extend(spring_courses)

    with open('catalog.json', 'w') as fout:
        json.dump(courses, fout)


if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
