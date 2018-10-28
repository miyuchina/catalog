port module Main exposing (init)

import Api exposing (..)
import Browser
import Dict exposing (Dict)
import Html exposing (Html, div, h1, input, label, li, section, span, text, ul)
import Html.Attributes exposing (class, hidden, id, placeholder, type_, value)
import Html.Events exposing (onClick, onInput)
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
    , expandedCourses : Set Int
    , displayMode : DisplayMode
    , searchResults : List Api.Course
    }


type DisplayMode
    = All
    | Search
    | Bucket


init : Bool -> ( Model, Cmd Msg )
init _ =
    ( { api = Api.emptyModel
      , page = 1
      , expandedCourses = Set.empty
      , displayMode = All
      , searchResults = []
      }
    , Cmd.map ApiMsg loadCourses
    )


type Msg
    = NoOp
    | LoadMore Bool
    | UserSearch String
    | ApiMsg Api.Msg
    | ToggleCourse Api.Course


port loadMore : (Bool -> msg) -> Sub msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

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
        [ div [ id "navbar" ]
            [ div [ id "navbar-inner" ]
                [ h1 []
                    [ span [ id "another" ] [ text "(ANOTHER)" ], text "CATALOG" ]
                ]
            ]
        , text model.api.error
        , div [ id "toolbar" ]
            [ input
                [ id "search"
                , type_ "text"
                , onInput UserSearch
                , placeholder "Search anything..."
                ]
                []
            , input
                [ type_ "button"
                , value "View Bucket"
                , class "tool-button"
                ]
                []
            , input
                [ type_ "button"
                , value "Go to..."
                , class "tool-button"
                ]
                []
            ]
        , viewCourses model
        ]
    }


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
                    model.api.courses


viewCourse : Model -> Api.Course -> Html Msg
viewCourse model course =
    div [ class "course" ] <|
        [ viewCourseHeader course ]
            ++ (if Set.member course.id model.expandedCourses then
                    [ viewCourseDetails model.api.details course ]

                else
                    []
               )


viewCourseHeader : Api.Course -> Html Msg
viewCourseHeader course =
    div [ class "course-header", onClick (ToggleCourse course) ]
        [ span [ class "course-id" ]
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
