module Api exposing (Course, Model, Msg, emptyModel, loadCourses, update)

import Http
import Json.Decode as D
import Json.Decode.Pipeline as P


type alias Model =
    { courses : List Course
    , error : String
    }


emptyModel : Model
emptyModel =
    { courses = []
    , error = ""
    }


type Msg
    = CoursesLoaded (Result Http.Error (List Course))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CoursesLoaded result ->
            case result of
                Ok courses ->
                    ( { model | courses = courses }, Cmd.none )

                Err err ->
                    ( { model | error = Debug.toString err }, Cmd.none )


type alias Course =
    { id : Int
    , dept : String
    , title : String
    , code : Int
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
    , instr : List String
    }


courseDecoder : D.Decoder Course
courseDecoder =
    let
        listify =
            D.map (String.split ";;") D.string
    in
    D.succeed Course
        |> P.required "id" D.int
        |> P.required "dept" D.string
        |> P.required "title" D.string
        |> P.required "code" D.int
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
        |> P.required "instr" listify


loadCourses : Cmd Msg
loadCourses =
    Http.send CoursesLoaded (Http.get "/api/courses" (D.list courseDecoder))
