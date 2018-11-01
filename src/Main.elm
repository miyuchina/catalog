port module Main exposing (init)

import Api exposing (..)
import Browser
import Color exposing (Color, black, white)
import Dict exposing (Dict)
import Html exposing (Html, a, div, form, h1, input, label, li, section, span, text, ul)
import Html.Attributes exposing (class, hidden, href, id, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, stopPropagationOn)
import Html.Lazy exposing (lazy, lazy4)
import Json.Decode as D
import Json.Encode as E
import Material.Icons.Action exposing (account_circle, bookmark, bookmark_border)
import Material.Icons.Content exposing (save)
import Material.Icons.Image exposing (collections, collections_bookmark)
import Material.Icons.Navigation exposing (close)
import Set exposing (Set)
import Svg exposing (Svg)


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
    , searchPage : Int
    , expandedCourses : Set Int
    , displayMode : DisplayMode
    , searchResults : List Api.Course
    }


perPage : Int
perPage =
    40


type DisplayMode
    = All
    | Search
    | Bucket


init : List Int -> ( Model, Cmd Msg )
init bucket =
    ( { api = Set.fromList bucket |> setBucket emptyModel
      , page = 1
      , searchPage = 1
      , expandedCourses = Set.empty
      , displayMode = All
      , searchResults = []
      }
    , [ loadCourses, checkLogin ]
        |> List.map (Cmd.map ApiMsg)
        |> Cmd.batch
    )


type Msg
    = NoOp
    | LoadMore Bool
    | UserSearch String
    | ApiMsg Api.Msg
    | ToggleBucket
    | ToggleInBucket Api.Course
    | ToggleCourse Api.Course


port loadMore : (Bool -> msg) -> Sub msg


port localBucket : E.Value -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        LoadMore _ ->
            case model.displayMode of
                All ->
                    ( { model | page = model.page + 1 }, Cmd.none )

                Search ->
                    ( { model | searchPage = model.searchPage + 1 }, Cmd.none )

                Bucket ->
                    ( model, Cmd.none )

        UserSearch searchTerm ->
            case searchTerm of
                "" ->
                    ( { model | displayMode = All, searchPage = 1 }
                    , Cmd.none
                    )

                _ ->
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
                    if Set.member course.id model.api.bucket then
                        Set.remove course.id model.api.bucket

                    else
                        Set.insert course.id model.api.bucket
            in
            ( { model
                | api =
                    setBucket model.api bucket
              }
            , localBucket <| E.set E.int bucket
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
                        Cmd.map ApiMsg <| loadCourseDetail course.id
            in
            ( { model | expandedCourses = expandedCourses }, cmd )


subscriptions : Model -> Sub Msg
subscriptions model =
    loadMore LoadMore


view : Model -> Browser.Document Msg
view model =
    { title = "(Another) Williams College Course Catalog"
    , body =
        [ lazy viewDialog model.api.dialog
        , lazy viewNavbar model.api.currentUser
        , lazy viewToolbar model.displayMode
        , viewCourses model
        ]
    }


viewNavbar : String -> Html Msg
viewNavbar currentUser =
    div [ id "navbar" ]
        [ div [ id "navbar-inner" ]
            [ h1 []
                [ span [ id "another" ] [ text "(ANOTHER)" ], text "CATALOG" ]
            , a [ href "/faq" ] [ text "FAQ" ]
            , a
                [ id "login"
                , href "#"
                , onClick <|
                    if String.isEmpty currentUser then
                        ApiMsg ShowLogin

                    else
                        NoOp
                ]
              <|
                if String.isEmpty currentUser then
                    [ text "Login" ]

                else
                    [ account_circle white 24
                    , text currentUser
                    , div [ id "dropdown" ]
                        [ span
                            [ onLocalClick <| ApiMsg ShowUserBuckets ]
                            [ text "My buckets" ]
                        , span
                            [ onLocalClick <| ApiMsg Logout
                            ]
                            [ text "Log out" ]
                        ]
                    ]
            ]
        ]


viewDialog : Dialog -> Html Msg
viewDialog dialog =
    div
        [ id "mask"
        , hidden <| String.isEmpty dialog.title
        , onClick <| ApiMsg ClearDialog
        ]
        [ div [ id "dialog", onLocalClick NoOp ]
            [ div
                [ id "close-dialog"
                , onClick <| ApiMsg ClearDialog
                ]
                [ close white 24 ]
            , h1 [ id "dialog-title" ] [ text dialog.title ]
            , div [ id "dialog-content" ] <|
                List.map (Html.map ApiMsg) dialog.content
            ]
        ]


viewToolbar : DisplayMode -> Html Msg
viewToolbar displayMode =
    let
        bucketText =
            case displayMode of
                Bucket ->
                    "View All"

                _ ->
                    "View Bucket"
    in
    div [ id "toolbar" ]
        [ input
            [ id "search"
            , type_ "text"
            , onInput UserSearch
            , placeholder "Search anything..."
            ]
            []
        , viewToolbarButton ToggleBucket collections_bookmark bucketText
        , viewToolbarButton (ApiMsg ShowSaveBucket) save "Save bucket"
        , viewToolbarButton (ApiMsg ShowLoadBucket) collections "Go to..."
        ]


viewToolbarButton : Msg -> Icon -> String -> Html Msg
viewToolbarButton msg icon content =
    a [ href "#", class "tool-button", onClick msg ] [ iconize icon, text content ]


viewCourses : Model -> Html Msg
viewCourses model =
    div [ id "courses" ] <|
        List.map
            (\c ->
                lazy4 viewCourse model.api.bucket model.expandedCourses model.api.details c
            )
        <|
            case model.displayMode of
                All ->
                    List.take (model.page * perPage) model.api.courses

                Search ->
                    List.take (model.searchPage * perPage) model.searchResults

                Bucket ->
                    List.filter
                        (\course -> Set.member course.id model.api.bucket)
                        model.api.courses


viewCourse : Set Int -> Set Int -> Dict Int Api.CourseDetail -> Api.Course -> Html Msg
viewCourse bucket expandedCourses details course =
    div [ class "course" ] <|
        [ viewCourseHeader (Set.member course.id bucket) course ]
            ++ (if Set.member course.id expandedCourses then
                    [ viewCourseDetails details course ]

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
            [ iconize <|
                if inBucket then
                    bookmark

                else
                    bookmark_border
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
        , ( "Class Number", [ String.fromInt section.nbr ] )
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


onLocalClick : Msg -> Html.Attribute Msg
onLocalClick msg =
    stopPropagationOn "click" <|
        D.map (\m -> ( m, True )) <|
            D.succeed msg


type alias Icon =
    Color -> Int -> Svg Msg


iconize : Icon -> Svg Msg
iconize icon =
    icon black 16


matchCourse : String -> Api.Course -> Bool
matchCourse searchTerm course =
    String.contains searchTerm course.searchable
