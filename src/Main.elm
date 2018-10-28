port module Main exposing (init)

import Api exposing (..)
import Browser
import Html exposing (Html, div, h1, input, li, section, span, text, ul)
import Html.Attributes exposing (class, hidden, id, type_)
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
            ( model, Cmd.none )

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
            in
            ( { model | expandedCourses = expandedCourses }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    loadMore LoadMore


view : Model -> Browser.Document Msg
view model =
    { title = "(Another) Williams College Course Catalog"
    , body =
        [ div [ id "navbar" ]
            [ h1 []
                [ span [ id "another" ] [ text "(Another)" ], text "Catalog" ]
            , input [ id "search", type_ "text", onInput UserSearch ] []
            ]
        , text model.api.error
        , viewCourses model
        ]
    }


viewCourses : Model -> Html Msg
viewCourses model =
    div [ id "courses" ] <|
        List.map
            (viewCourse model.expandedCourses)
        <|
            case model.displayMode of
                All ->
                    model.api.courses

                Search ->
                    model.searchResults

                Bucket ->
                    model.api.courses


viewCourse : Set Int -> Api.Course -> Html Msg
viewCourse expandedCourses course =
    div [ class "course" ]
        [ viewCourseHeader course
        , viewCourseDetails expandedCourses course
        ]


viewCourseHeader : Api.Course -> Html Msg
viewCourseHeader course =
    div [ class "course-header", onClick (ToggleCourse course) ]
        [ span [ class "course-id" ]
            [ text <| course.dept ++ " " ++ String.fromInt course.code ]
        , span [ class "course-title" ] [ text course.title ]
        , span [ class "course-instr" ]
            (List.map (\instr -> div [] [ text instr ]) course.instr)
        ]


viewCourseDetails : Set Int -> Api.Course -> Html Msg
viewCourseDetails expandedCourses course =
    div
        [ class "course-details"
        , hidden <| not <| Set.member course.id expandedCourses
        ]
        [ section [ class "course-desc" ] [ text course.desc ]
        , viewCourseSpecifics course
        ]


viewCourseSpecifics : Api.Course -> Html Msg
viewCourseSpecifics course =
    div [ class "course-specifics" ]
        (List.map viewKeyValue
            [ ( "Class Type", [ course.type_ ] )
            , ( "Limit", [ course.limit ] )
            , ( "Expected", [ course.expected ] )
            , ( "Divisions", course.dreqs )
            , ( "Distributions", course.divattr )
            , ( "Distribution Notes", course.distnote )
            , ( "Department Notes", course.deptnote )
            , ( "Prerequisites", course.prerequisites )
            , ( "Requirements / Evaluation", course.rqmtseval )
            , ( "Material / Lab Fee", course.matlfee )
            , ( "Extra Info", course.extrainfo )
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
