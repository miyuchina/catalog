module Api exposing (Course, CourseDetail, CourseSection, Dialog, Model, Msg(..), Term(..), checkLogin, emptyModel, loadCourseDetail, loadCourses, setBucket, update)

import Dict exposing (Dict)
import Html exposing (Html, a, form, input, p, text)
import Html.Attributes exposing (class, hidden, id, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as D
import Json.Decode.Pipeline as P
import Json.Encode as E
import Set exposing (Set)


type alias Model =
    { courses : List Course
    , details : Dict Int CourseDetail
    , currentUser : String
    , username : String
    , password : String
    , bucketName : String
    , bucket : Set Int
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
    , bucketName = ""
    , bucket = Set.empty
    , dialog = { title = "", content = [] }
    }


setBucket : Model -> Set Int -> Model
setBucket model bucket =
    { model | bucket = bucket }


type Msg
    = CoursesLoaded String (Result Http.Error (List Course))
    | CourseDetailLoaded (Result Http.Error CourseDetail)
    | LoginResponse (Result Http.Error UserResponse)
    | RegisterResponse (Result Http.Error UserResponse)
    | LoginStatusResponse (Result Http.Error (Maybe String))
    | LogoutResponse (Result Http.Error UserResponse)
    | LoadBucketResponse (Result Http.Error BucketResponse)
    | SaveBucketResponse (Result Http.Error BucketResponse)
    | UserBucketsResponse (Result Http.Error UserBuckets)
    | ClearDialog
    | ShowLogin
    | ShowRegister
    | ShowSaveBucket
    | ShowLoadBucket
    | ShowUserBuckets
    | Login
    | Register
    | Logout
    | SaveBucket
    | LoadBucket
    | LoadBucketWithName String
    | EnteredUsername String
    | EnteredPassword String
    | EnteredBucketName String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CoursesLoaded termString result ->
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

        LoginStatusResponse result ->
            case result of
                Ok res ->
                    case res of
                        Just currentUser ->
                            ( { model | currentUser = currentUser }, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        LogoutResponse result ->
            case result of
                Ok userResponse ->
                    ( { model
                        | dialog = textDialog "Success" userResponse.msg
                        , currentUser = ""
                      }
                    , Cmd.none
                    )

                Err err ->
                    handleHttpError model err

        SaveBucketResponse result ->
            case result of
                Ok bucketResponse ->
                    case bucketResponse.success of
                        True ->
                            ( { model
                                | dialog = textDialog "Success" bucketResponse.msg
                              }
                            , Cmd.none
                            )

                        False ->
                            ( { model
                                | dialog = textDialog "Error" bucketResponse.msg
                                , bucketName = ""
                              }
                            , Cmd.none
                            )

                Err err ->
                    handleHttpError model err

        UserBucketsResponse result ->
            case result of
                Ok response ->
                    case response.success of
                        True ->
                            ( { model
                                | dialog =
                                    userBucketsDialog model.currentUser response.names
                              }
                            , Cmd.none
                            )

                        False ->
                            ( { model
                                | dialog = textDialog "Error" response.msg
                                , bucketName = ""
                              }
                            , Cmd.none
                            )

                Err err ->
                    handleHttpError model err

        LoadBucketResponse result ->
            case result of
                Ok bucketResponse ->
                    case bucketResponse.success of
                        True ->
                            ( { model
                                | dialog = textDialog "Success" bucketResponse.msg
                                , bucket = bucketResponse.courses
                              }
                            , Cmd.none
                            )

                        False ->
                            ( { model
                                | dialog = textDialog "Error" bucketResponse.msg
                                , bucketName = ""
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

        ShowSaveBucket ->
            ( { model | dialog = saveBucketDialog }
            , Cmd.none
            )

        ShowLoadBucket ->
            ( { model | dialog = loadBucketDialog }
            , Cmd.none
            )

        ShowUserBuckets ->
            ( model, showUserBuckets )

        Login ->
            ( model, login model.username model.password )

        Register ->
            ( model, register model.username model.password )

        Logout ->
            ( model, logout )

        SaveBucket ->
            ( model, saveBucket model.bucketName model.bucket )

        LoadBucket ->
            ( model, loadBucket model.bucketName )

        LoadBucketWithName name ->
            ( model, loadBucket name )

        EnteredUsername username ->
            ( { model | username = username }, Cmd.none )

        EnteredPassword password ->
            ( { model | password = password }, Cmd.none )

        EnteredBucketName bucketName ->
            ( { model | bucketName = bucketName }, Cmd.none )

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
    , nbr : Int
    }


type Term
    = F2019
    | S2020
    | UnknownTerm


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
        |> P.required "nbr" D.int


listify : D.Decoder (List String)
listify =
    D.map (String.split ";;") D.string


loadCourses : Term -> Cmd Msg
loadCourses term =
    let
        termString =
            case term of
                F2019 ->
                    "fall-2019"

                S2020 ->
                    "spring-2020"

                _ ->
                    ""
    in
    Http.send (CoursesLoaded termString) <|
        Http.get ("/api/courses/" ++ termString) (D.list courseDecoder)


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


checkLogin : Cmd Msg
checkLogin =
    Http.send LoginStatusResponse <|
        Http.get "/api/user/login" (D.nullable D.string)


logout : Cmd Msg
logout =
    Http.send LogoutResponse <|
        Http.post "/api/user/logout" Http.emptyBody userResponseDecoder


userResponseDecoder : D.Decoder UserResponse
userResponseDecoder =
    D.map2 UserResponse
        (D.field "success" D.bool)
        (D.field "msg" D.string)


type alias BucketResponse =
    { success : Bool
    , msg : String
    , courses : Set Int
    }


type alias UserBuckets =
    { success : Bool
    , msg : String
    , names : List String
    }


saveBucket : String -> Set Int -> Cmd Msg
saveBucket name bucket =
    let
        bucketString =
            Set.toList bucket
                |> List.map String.fromInt
                |> String.join ";;"

        json =
            E.object [ ( "courses", E.string bucketString ) ]
    in
    Http.send SaveBucketResponse <|
        Http.post ("/api/bucket/" ++ name)
            (Http.jsonBody json)
            bucketResponseDecoder


loadBucket : String -> Cmd Msg
loadBucket name =
    Http.send LoadBucketResponse <|
        Http.get ("/api/bucket/" ++ name) bucketResponseDecoder


showUserBuckets : Cmd Msg
showUserBuckets =
    Http.send UserBucketsResponse <|
        Http.get "/api/user/buckets" userBucketsDecoder


bucketResponseDecoder : D.Decoder BucketResponse
bucketResponseDecoder =
    let
        toIntOrZero s =
            String.toInt s
                |> Maybe.withDefault 0
    in
    D.map3 BucketResponse
        (D.field "success" D.bool)
        (D.field "msg" D.string)
        (D.field "courses" <|
            D.map
                (\s ->
                    String.split ";;" s
                        |> List.map toIntOrZero
                        |> Set.fromList
                )
                D.string
        )


userBucketsDecoder =
    D.map3 UserBuckets
        (D.field "success" D.bool)
        (D.field "msg" D.string)
        (D.field "names" (D.list D.string))


textDialog : String -> String -> Dialog
textDialog title content =
    Dialog title [ text content ]


loginDialog : Dialog
loginDialog =
    { title = "Log in"
    , content =
        [ p [] [ text "You cannot use your Williams account here..." ]
        , form [ onSubmit Login ]
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


saveBucketDialog : Dialog
saveBucketDialog =
    { title = "Save bucket"
    , content =
        [ form [ onSubmit SaveBucket ]
            [ input
                [ onInput EnteredBucketName
                , type_ "text"
                , placeholder "Name your bucket!"
                ]
                []
            , input
                [ class "dialog-button"
                , type_ "submit"
                , value "Save"
                ]
                []
            ]
        ]
    }


loadBucketDialog : Dialog
loadBucketDialog =
    { title = "Go to bucket..."
    , content =
        [ form [ onSubmit LoadBucket ]
            [ input
                [ onInput EnteredBucketName
                , type_ "text"
                , placeholder "Which bucket do you want?"
                ]
                []
            , input
                [ class "dialog-button"
                , type_ "submit"
                , value "Visit bucket"
                ]
                []
            ]
        ]
    }


userBucketsDialog : String -> List String -> Dialog
userBucketsDialog username names =
    { title = username ++ "'s buckets"
    , content =
        List.map
            (\name -> a [ onClick <| LoadBucketWithName name ] [ text name ])
            names
    }
