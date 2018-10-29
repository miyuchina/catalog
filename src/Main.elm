port module Main exposing (init)

import Api exposing (..)
import Browser
import Dict exposing (Dict)
import Html exposing (Html, a, div, h1, input, label, li, section, span, text, ul)
import Html.Attributes exposing (class, hidden, href, id, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, stopPropagationOn)
import Json.Decode as D
import Set exposing (Set)


main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { api : Api.Model
    , page : Int
    , dialog : Dialog
    , bucket : Set Int
    , expandedCourses : Set Int
    , displayMode : DisplayMode
    , searchResults : List Api.Course
    }


type DisplayMode
    = All
    | Search
    | Bucket


type alias Dialog =
    { title : String
    , content : List (Html Msg)
    }


init : Bool -> ( Model, Cmd Msg )
init _ =
    ( { api = Api.emptyModel
      , page = 1
      , dialog = { title = "", content = [] }
      , bucket = Set.empty
      , expandedCourses = Set.empty
      , displayMode = All
      , searchResults = []
      }
    , Cmd.map ApiMsg loadCourses
    )


type Msg
    = NoOp
    | ShowLogin
    | ClearDialog
    | LoadMore Bool
    | UserSearch String
    | ApiMsg Api.Msg
    | ToggleBucket
    | ToggleInBucket Api.Course
    | ToggleCourse Api.Course


port loadMore : (Bool -> msg) -> Sub msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ShowLogin ->
            ( { model | dialog = loginDialog }
            , Cmd.none
            )

        ClearDialog ->
            ( { model | dialog = { title = "", content = [] } }
            , Cmd.none
            )

        LoadMore _ ->
            ( { model | page = model.page + 1 }, Cmd.none )

        UserSearch searchTerm ->
            ( { model
                | displayMode = Search
                , searchResults =
                    List.filter
                        (matchCourse <| String.toLower searchTerm)
                        model.api.courses
              }
            , Cmd.none
            )

        ApiMsg apiMsg ->
            let
                ( apiModel, apiCmd ) =
                    Api.update apiMsg model.api
            in
            ( { model | api = apiModel }
            , Cmd.map ApiMsg apiCmd
            )

        ToggleBucket ->
            let
                displayMode =
                    case model.displayMode of
                        All ->
                            Bucket

                        Search ->
                            Bucket

                        Bucket ->
                            All
            in
            ( { model | displayMode = displayMode }, Cmd.none )

        ToggleInBucket course ->
            let
                bucket =
                    if Set.member course.id model.bucket then
                        Set.remove course.id model.bucket

                    else
                        Set.insert course.id model.bucket
            in
            ( { model | bucket = bucket }, Cmd.none )

        ToggleCourse course ->
            let
                expandedCourses =
                    if Set.member course.id model.expandedCourses then
                        Set.remove course.id model.expandedCourses

                    else
                        Set.insert course.id model.expandedCourses

                cmd =
                    if Dict.member course.id model.api.details then
                        Cmd.none

                    else
                        Cmd.map ApiMsg <| Api.loadCourseDetail course.id
            in
            ( { model | expandedCourses = expandedCourses }, cmd )


subscriptions : Model -> Sub Msg
subscriptions model =
    loadMore LoadMore


view : Model -> Browser.Document Msg
view model =
    { title = "(Another) Williams College Course Catalog"
    , body =
        [ text model.api.error
        , viewDialog model
        , viewNavbar model
        , viewToolbar model.displayMode
        , viewCourses model
        ]
    }


viewNavbar : Model -> Html Msg
viewNavbar model =
    div [ id "navbar" ]
        [ div [ id "navbar-inner" ]
            [ h1 []
                [ span [ id "another" ] [ text "(ANOTHER)" ], text "CATALOG" ]
            , a [ href "/faq" ] [ text "FAQ" ]
            , a [ href "#", onClick ShowLogin ] [ text "Login" ]
            ]
        ]


viewDialog : Model -> Html Msg
viewDialog model =
    div
        [ id "mask"
        , hidden <| String.isEmpty model.dialog.title
        , onClick ClearDialog
        ]
        [ div [ id "dialog", onLocalClick NoOp ]
            [ h1 [ id "dialog-title" ] [ text model.dialog.title ]
            , div [ id "dialog-content" ]
                model.dialog.content
            ]
        ]


viewToolbar : DisplayMode -> Html Msg
viewToolbar displayMode =
    div [ id "toolbar" ]
        [ input
            [ id "search"
            , type_ "text"
            , onInput UserSearch
            , placeholder "Search anything..."
            ]
            []
        , input
            [ type_ "button"
            , value <|
                case displayMode of
                    Bucket ->
                        "View All"

                    _ ->
                        "View Bucket"
            , class "tool-button"
            , onClick ToggleBucket
            ]
            []
        , input
            [ type_ "button"
            , value "Go to..."
            , class "tool-button"
            ]
            []
        ]


viewCourses : Model -> Html Msg
viewCourses model =
    div [ id "courses" ] <|
        List.map
            (viewCourse model)
        <|
            case model.displayMode of
                All ->
                    List.take (model.page * 30) model.api.courses

                Search ->
                    model.searchResults

                Bucket ->
                    List.filter
                        (\course -> Set.member course.id model.bucket)
                        model.api.courses


viewCourse : Model -> Api.Course -> Html Msg
viewCourse model course =
    div [ class "course" ] <|
        [ viewCourseHeader (Set.member course.id model.bucket) course ]
            ++ (if Set.member course.id model.expandedCourses then
                    [ viewCourseDetails model.api.details course ]

                else
                    []
               )


viewCourseHeader : Bool -> Api.Course -> Html Msg
viewCourseHeader inBucket course =
    div [ class "course-header", onClick (ToggleCourse course) ]
        [ span
            [ class "add-to-bucket"
            , onLocalClick <| ToggleInBucket course
            , hidden <| not inBucket
            ]
            [ text <|
                if inBucket then
                    "✔"

                else
                    "+"
            ]
        , span [ class "course-id" ]
            [ text <| course.dept ++ " " ++ String.fromInt course.code ]
        , span [ class "course-title" ] [ text course.title ]
        , span [ class "course-instr" ]
            (List.map (\instr -> div [] [ text instr ]) course.instr)
        ]


viewCourseDetails : Dict Int Api.CourseDetail -> Api.Course -> Html Msg
viewCourseDetails details course =
    let
        content =
            case Dict.get course.id details of
                Just detail ->
                    [ section [ class "course-desc" ] [ text detail.desc ]
                    , viewCourseSpecifics detail
                    ]
                        ++ List.map
                            (\section ->
                                div [ class "course-sections" ] <|
                                    viewCourseSection section
                            )
                            detail.sections
                        ++ [ div
                                [ class "collapse"
                                , onClick (ToggleCourse course)
                                ]
                                [ text "▲ Collapse" ]
                           ]

                Nothing ->
                    [ text "loading..." ]
    in
    div [ class "course-details" ] content


viewCourseSpecifics : Api.CourseDetail -> Html Msg
viewCourseSpecifics detail =
    div [ class "course-specifics" ]
        (List.map viewKeyValue
            [ ( "Class Type", [ detail.type_ ] )
            , ( "Limit", [ detail.limit ] )
            , ( "Expected", [ detail.expected ] )
            , ( "Divisions", detail.dreqs )
            , ( "Distributions", detail.divattr )
            , ( "Distribution Notes", detail.distnote )
            , ( "Department Notes", detail.deptnote )
            , ( "Prerequisites", detail.prerequisites )
            , ( "Requirements / Evaluation", detail.rqmtseval )
            , ( "Material / Lab Fee", detail.matlfee )
            , ( "Extra Info", detail.extrainfo )
            ]
        )


viewCourseSection : Api.CourseSection -> List (Html Msg)
viewCourseSection section =
    List.map viewKeyValue
        [ ( "Section Type", [ section.type_ ] )
        , ( "Time", section.tp )
        , ( "Instructors", section.instr )
        ]


viewKeyValue : ( String, List String ) -> Html Msg
viewKeyValue ( key, values ) =
    case values of
        [] ->
            text ""

        [ "" ] ->
            text ""

        [ value ] ->
            div [ class "specifics-row" ]
                [ span [ class "specifics-key" ] [ text key ]
                , span [ class "specifics-value" ] [ text value ]
                ]

        _ ->
            div [ class "specifics-row" ]
                [ span [ class "specifics-key" ] [ text key ]
                , ul [ class "specifics-value" ] <|
                    List.map
                        (\e ->
                            if String.isEmpty e then
                                text e

                            else
                                li [] [ text e ]
                        )
                        values
                ]


loginDialog : Dialog
loginDialog =
    { title = ""
    , content =
        []
    }


onLocalClick : Msg -> Html.Attribute Msg
onLocalClick msg =
    stopPropagationOn "click" <|
        D.map (\m -> ( m, True )) <|
            D.succeed msg


matchCourse : String -> Api.Course -> Bool
matchCourse searchTerm course =
    String.contains
        searchTerm
    <|
        String.join
            " "
        <|
            List.map String.toLower
                [ course.dept ++ " " ++ String.fromInt course.code
                , course.title
                , String.join " " course.instr
                ]
