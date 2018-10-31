module Api exposing (Course, CourseDetail, CourseSection, Dialog, Model, Msg(..), emptyModel, loadCourseDetail, loadCourses, update)

import Dict exposing (Dict)
import Html exposing (Html, form, input, text)
import Html.Attributes exposing (class, hidden, id, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as D
import Json.Decode.Pipeline as P
import Json.Encode as E


type alias Model =
    { courses : List Course
    , details : Dict Int CourseDetail
    , currentUser : String
    , username : String
    , password : String
    , dialog : Dialog
    }


type alias Dialog =
    { title : String
    , content : List (Html Msg)
    }


emptyModel : Model
emptyModel =
    { courses = []
    , details = Dict.empty
    , currentUser = ""
    , username = ""
    , password = ""
    , dialog = { title = "", content = [] }
    }


type Msg
    = CoursesLoaded (Result Http.Error (List Course))
    | CourseDetailLoaded (Result Http.Error CourseDetail)
    | LoginResponse (Result Http.Error UserResponse)
    | RegisterResponse (Result Http.Error UserResponse)
    | ClearDialog
    | ShowLogin
    | ShowRegister
    | Login
    | Register
    | EnteredUsername String
    | EnteredPassword String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CoursesLoaded result ->
            case result of
                Ok courses ->
                    ( { model | courses = courses }, Cmd.none )

                Err err ->
                    handleHttpError model err

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
                    handleHttpError model err

        LoginResponse result ->
            case result of
                Ok userResponse ->
                    case userResponse.success of
                        True ->
                            ( { model
                                | currentUser = model.username
                                , username = ""
                                , password = ""
                                , dialog = textDialog "Success" userResponse.msg
                              }
                            , Cmd.none
                            )

                        False ->
                            ( { model
                                | username = ""
                                , password = ""
                                , dialog = textDialog "Error" userResponse.msg
                              }
                            , Cmd.none
                            )

                Err err ->
                    handleHttpError model err

        RegisterResponse result ->
            case result of
                Ok userResponse ->
                    case userResponse.success of
                        True ->
                            ( { model
                                | username = ""
                                , password = ""
                                , dialog = textDialog "Success" userResponse.msg
                              }
                            , Cmd.none
                            )

                        False ->
                            ( { model
                                | username = ""
                                , password = ""
                                , dialog = textDialog "Error" userResponse.msg
                              }
                            , Cmd.none
                            )

                Err err ->
                    handleHttpError model err

        ShowLogin ->
            ( { model | dialog = loginDialog }
            , Cmd.none
            )

        ShowRegister ->
            ( { model | dialog = registerDialog }
            , Cmd.none
            )

        Login ->
            ( model, login model.username model.password )

        Register ->
            ( model, register model.username model.password )

        EnteredUsername username ->
            ( { model | username = username }, Cmd.none )

        EnteredPassword password ->
            ( { model | password = password }, Cmd.none )

        ClearDialog ->
            ( { model | dialog = { title = "", content = [] } }
            , Cmd.none
            )


handleHttpError : Model -> Http.Error -> ( Model, Cmd Msg )
handleHttpError model err =
    ( { model
        | dialog = textDialog "Error" "Something went wrong..."
      }
    , Cmd.none
    )


type alias Course =
    { id : Int
    , dept : String
    , title : String
    , code : Int
    , instr : List String
    , searchable : String
    }


makeCourse : Int -> String -> String -> Int -> List String -> Course
makeCourse id dept title code instr =
    let
        searchable =
            String.join " " <|
                List.map String.toLower
                    [ dept ++ " " ++ String.fromInt code
                    , title
                    , String.join " " instr
                    ]
    in
    Course id dept title code instr searchable


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
    D.succeed makeCourse
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


type alias UserResponse =
    { success : Bool
    , msg : String
    }


login : String -> String -> Cmd Msg
login username password =
    let
        json =
            E.object
                [ ( "username", E.string username )
                , ( "password", E.string password )
                ]
    in
    Http.send LoginResponse <|
        Http.post "/api/user/login" (Http.jsonBody json) userResponseDecoder


register : String -> String -> Cmd Msg
register username password =
    let
        json =
            E.object
                [ ( "username", E.string username )
                , ( "password", E.string password )
                ]
    in
    Http.send RegisterResponse <|
        Http.post "/api/user/register" (Http.jsonBody json) userResponseDecoder


userResponseDecoder : D.Decoder UserResponse
userResponseDecoder =
    D.map2 UserResponse
        (D.field "success" D.bool)
        (D.field "msg" D.string)


textDialog : String -> String -> Dialog
textDialog title content =
    Dialog title [ text content ]


loginDialog : Dialog
loginDialog =
    { title = "Log in"
    , content =
        [ form [ onSubmit Login ]
            [ input
                [ onInput EnteredUsername
                , type_ "text"
                , placeholder "Username"
                ]
                []
            , input
                [ onInput EnteredPassword
                , type_ "password"
                , placeholder "Password"
                ]
                []
            , input
                [ class "dialog-button"
                , type_ "button"
                , value "Register"
                , onClick ShowRegister
                ]
                []
            , input
                [ class "dialog-button"
                , type_ "submit"
                , value "Log in"
                ]
                []
            ]
        ]
    }


registerDialog : Dialog
registerDialog =
    { title = "Register"
    , content =
        [ form [ onSubmit Register ]
            [ input
                [ onInput EnteredUsername
                , type_ "text"
                , placeholder "Username"
                ]
                []
            , input
                [ onInput EnteredPassword
                , type_ "password"
                , placeholder "Password"
                ]
                []
            , input
                [ class "dialog-button"
                , type_ "button"
                , value "Login"
                , onClick ShowLogin
                ]
                []
            , input
                [ class "dialog-button"
                , type_ "submit"
                , value "Register"
                ]
                []
            ]
        ]
    }
