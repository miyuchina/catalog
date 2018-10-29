module Api exposing (Course, CourseDetail, CourseSection, Model, Msg, emptyModel, loadCourseDetail, loadCourses, update)

import Dict exposing (Dict)
import Http
import Json.Decode as D
import Json.Decode.Pipeline as P


type alias Model =
    { courses : List Course
    , details : Dict Int CourseDetail
    , error : String
    }


emptyModel : Model
emptyModel =
    { courses = []
    , details = Dict.empty
    , error = ""
    }


type Msg
    = CoursesLoaded (Result Http.Error (List Course))
    | CourseDetailLoaded (Result Http.Error CourseDetail)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CoursesLoaded result ->
            case result of
                Ok courses ->
                    ( { model | courses = courses }, Cmd.none )

                Err err ->
                    ( { model | error = "error" }, Cmd.none )

        CourseDetailLoaded result ->
            case result of
                Ok detail ->
                    ( { model
                        | details =
                            Dict.insert detail.id detail model.details
                      }
                    , Cmd.none
                    )

                Err err ->
                    ( { model | error = "error" }, Cmd.none )


type alias Course =
    { id : Int
    , dept : String
    , title : String
    , code : Int
    , instr : List String
    }


type alias CourseDetail =
    { id : Int
    , desc : String
    , deptnote : List String
    , distnote : List String
    , divattr : List String
    , dreqs : List String
    , enrollmentpref : List String
    , expected : String
    , limit : String
    , matlfee : List String
    , prerequisites : List String
    , rqmtseval : List String
    , extrainfo : List String
    , type_ : String
    , sections : List CourseSection
    }


type alias CourseSection =
    { type_ : String
    , instr : List String
    , tp : List String
    }


courseDecoder : D.Decoder Course
courseDecoder =
    D.succeed Course
        |> P.required "id" D.int
        |> P.required "dept" D.string
        |> P.required "title" D.string
        |> P.required "code" D.int
        |> P.required "instr" listify


courseDetailDecoder : D.Decoder CourseDetail
courseDetailDecoder =
    D.succeed CourseDetail
        |> P.required "id" D.int
        |> P.required "desc" D.string
        |> P.required "deptnote" listify
        |> P.required "distnote" listify
        |> P.required "divattr" listify
        |> P.required "dreqs" listify
        |> P.required "enrollmentpref" listify
        |> P.required "expected" D.string
        |> P.required "limit_" D.string
        |> P.required "matlfee" listify
        |> P.required "prerequisites" listify
        |> P.required "rqmtseval" listify
        |> P.required "extrainfo" listify
        |> P.required "type" D.string
        |> P.required "section" (D.list courseSectionDecoder)


courseSectionDecoder : D.Decoder CourseSection
courseSectionDecoder =
    D.succeed CourseSection
        |> P.required "type" D.string
        |> P.required "instr" listify
        |> P.required "tp" listify


listify : D.Decoder (List String)
listify =
    D.map (String.split ";;") D.string


loadCourses : Cmd Msg
loadCourses =
    Http.send CoursesLoaded <|
        Http.get "/api/courses" (D.list courseDecoder)


loadCourseDetail : Int -> Cmd Msg
loadCourseDetail id =
    Http.send CourseDetailLoaded <|
        Http.get ("/api/course/" ++ String.fromInt id) courseDetailDecoder
