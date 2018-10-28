'use strict';

const courses = {
    data : [],
    page : 0,
    perPage : 50,
    searchMode : false,
    canvas : document.getElementById('courses'),

    init : function() {
        const req = new XMLHttpRequest();

        req.addEventListener("load", function() {
            courses.update(JSON.parse(this.responseText));
            courses.render();
            courses.data.forEach((course) => {
                course.searchable =
                    [course.dept, course.code, course.title, list(course.instr).join(' ')]
                        .join(' ')
                        .toLowerCase();
            });
        });

        req.addEventListener("error", function() {
            alert("Failed fetching courses, check back later?");
        });

        req.open("GET", "/api/courses");
        req.send();
    },

    update : function(new_courses) {
        this.data = [...this.data, ...new_courses];
    },

    render : function() {
        if (!this.searchMode) {
            const frag = document.createDocumentFragment();
            this.data.slice(this.page * this.perPage, ++this.page * this.perPage)
                .forEach((course) => {
                    frag.appendChild(this.renderCourse(course));
                });
            this.canvas.appendChild(frag);
        }
    },

    search : function(searchTerm) {
        searchTerm = searchTerm.toLowerCase();
        const frag = document.createDocumentFragment();
        if (searchTerm === '') {
            this.searchMode = false;
            this.data.slice(0, this.page * this.perPage)
                .forEach((course) => {
                    frag.appendChild(this.renderCourse(course));
                });
        } else {
            this.searchMode = true;
            this.canvas.innerHTML = '';
            this.data.forEach((course) => {
                if (course.searchable.includes(searchTerm)) {
                    frag.appendChild(this.renderCourse(course));
                } else {
                    if (course.dept === 'ENGL')
                        console.log(course.searchable);
                }
            })
        }
        this.canvas.appendChild(frag);
    },

    renderCourse : function(course) {
        if (course.html === undefined) {
            const element = el('div', {'class': 'course'}, [
                el('div', {'class': 'course_header'}, [
                    el('span', {'class': 'course_id'}, course.dept + ' ' + course.code),
                    el('span', {'class': 'course_title'}, course.title),
                    el('span', {'class': 'course_instructors'},
                        list(course.instr).map((i) => el('span', {}, i) )),
                ]),
            ]);
            element.firstChild.addEventListener('click', function(event) {
                courses.toggleCourse(course);
            }, false);
            course.html = element;
        }
        return course.html;
    },

    toggleCourse : function(course) {
        if (course.hidden === undefined) {
            const element = el('div', {'class': 'course_details'}, [
                el('section', {'class': 'course_desc'}, course.desc),
                el('div', {'class': 'specifics'}, [
                    renderKeyValue('Class Type', course.type),
                    renderKeyValue('Limit', course.limit_.toString()),
                    renderKeyValue('Expected', course.expected.toString()),
                    renderKeyValue('Prerequisites', course.prerequisites),
                    renderKeyValue('Enrollment Preference', course.enrollmentpref),
                    renderKeyValue('Requirements/Evaluation', course.rqmtseval),
                    renderKeyValue('Attributes', course.divattr),
                    renderKeyValue('Distribution Notes', course.distnote),
                    renderKeyValue('Department Notes', course.deptnote),
                    renderKeyValue('Materials/Lab Fee', course.matlfee),
                    renderKeyValue('Extra Info', course.extrainfo),
                ]),
            ]);
            course.html.appendChild(element);
            course.html.lastChild.hidden = course.hidden = false;
        } else if (course.hidden === true) {
            course.html.lastChild.hidden = course.hidden = false;
        } else {
            course.html.lastChild.hidden = course.hidden = true;
        }
    },

    fetchCourseDetails : function (course_id) {
        const req = new XMLHttpRequest();

        req.addEventListener("load", function() {
            console.log(JSON.parse(this.responseText));
        });

        req.addEventListener("error", function() {
            alert("Failed fetching details, check back later?");
        });

        req.open("GET", "/api/course/" + course_id);
        req.send();
    }
}

function el(tagname, attrs, children) {
    const element = document.createElement(tagname);
    Object.entries(attrs).forEach(([key, value]) => {
        element.setAttribute(key, value);
    });
    if (typeof children === 'string') {
        element.appendChild(document.createTextNode(children))
    } else {
        children.forEach((child) => element.appendChild(child));
    }
    return element;
}

function list(str) {
    return str.split(";;");
}

function renderKeyValue(key, value) {
    if (value === 0 || value === '' || value === [])
        return document.createTextNode('');
    value = list(value);
    const valueTag = el('span', {'class': 'value'},
        value.length === 1 ? value[0] : value.map((v) => el('li', {}, v))
    );
    return el('div', {'class': 'row'}, [el('span', {'class': 'key'}, key), valueTag]);
}

courses.init();

window.onscroll = () => {
    const bottom = window.scrollY + window.innerHeight;
    const scrollPercentage = bottom / document.body.scrollHeight;
    if (scrollPercentage > 0.9)
        courses.render();
}

document.getElementById('search').addEventListener('keydown', function(event) {
    courses.search(event.target.value);
}, false);
