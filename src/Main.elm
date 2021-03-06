port module Main exposing (init)

import Api exposing (..)
import Browser
import Browser.Dom as Dom
import Browser.Events as Events
import Browser.Navigation as Nav
import Color exposing (Color, black, white)
import Dict exposing (Dict)
import Html exposing (Html, a, div, form, h1, input, label, li, option, section, select, span, text, ul)
import Html.Attributes exposing (action, attribute, autocomplete, class, hidden, href, id, placeholder, spellcheck, type_, value)
import Html.Events exposing (keyCode, onClick, onInput, onSubmit, stopPropagationOn)
import Html.Lazy exposing (lazy, lazy2, lazy4)
import Json.Decode as D
import Json.Encode as E
import Material.Icons.Action exposing (account_circle, bookmark, bookmark_border, date_range)
import Material.Icons.Content exposing (save)
import Material.Icons.Image exposing (collections, collections_bookmark)
import Material.Icons.Navigation exposing (close)
import Set exposing (Set)
import Svg exposing (Svg)
import Task
import Url
import Url.Parser as P exposing ((</>))


main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


type alias Model =
    { api : Api.Model
    , page : Int
    , searchPage : Int
    , expandedCourses : Set Int
    , displayMode : DisplayMode
    , url : Url.Url
    }


perPage : Int
perPage =
    40


type DisplayMode
    = All
    | Search
    | Bucket


type Route
    = BucketRoute String
    | UnknownRoute


init : List Int -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init bucket url key =
    let
        initCmdList =
            [ Cmd.map ApiMsg (loadCourses F2019)
            , Cmd.map ApiMsg checkLogin
            ]

        ( displayMode, cmdList ) =
            case Maybe.withDefault UnknownRoute <| P.parse routeParser url of
                UnknownRoute ->
                    ( All, initCmdList )

                BucketRoute bucketName ->
                    ( Bucket, Cmd.map ApiMsg (loadBucket bucketName) :: initCmdList )
    in
    ( { api = Set.fromList bucket |> setBucket (emptyModel key)
      , page = 1
      , searchPage = 1
      , expandedCourses = Set.empty
      , displayMode = displayMode
      , url = url
      }
    , Cmd.batch cmdList
    )


type Msg
    = NoOp
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | LoadMore Bool
    | UserSearch String
    | SubmitSearch
    | ApiMsg Api.Msg
    | ToggleBucket
    | ToggleInBucket Api.Course
    | ToggleCourse Api.Course
    | SelectTerm String
    | GoToIndex


port loadMore : (Bool -> msg) -> Sub msg


port localBucket : E.Value -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.api.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            route model url

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
                    ( { model
                        | displayMode = All
                        , searchPage = 1
                        , api = updateSearchResults model.api searchTerm
                      }
                    , Cmd.none
                    )

                _ ->
                    ( { model
                        | displayMode = Search
                        , api = updateSearchResults model.api searchTerm
                      }
                    , Cmd.none
                    )

        SubmitSearch ->
            ( model, Task.attempt (\_ -> NoOp) (Dom.blur "search") )

        ApiMsg apiMsg ->
            let
                ( apiModel, apiCmd ) =
                    Api.update apiMsg model.api

                displayMode =
                    case apiMsg of
                        GoToBucket ->
                            Bucket

                        _ ->
                            model.displayMode
            in
            ( { model | api = apiModel, displayMode = displayMode }
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

        SelectTerm termString ->
            let
                term =
                    case termString of
                        "fall-2019" ->
                            F2019

                        "spring-2020" ->
                            S2020

                        _ ->
                            UnknownTerm
            in
            ( model, Cmd.map ApiMsg <| loadCourses term )

        GoToIndex ->
            ( model, Nav.load "/" )


route : Model -> Url.Url -> ( Model, Cmd Msg )
route model url =
    case Maybe.withDefault UnknownRoute <| P.parse routeParser url of
        BucketRoute bucketName ->
            ( { model | url = url, displayMode = Bucket }
            , Cmd.map ApiMsg <| loadBucket bucketName
            )

        UnknownRoute ->
            ( model, Nav.load <| Url.toString url )


routeParser : P.Parser (Route -> a) a
routeParser =
    P.oneOf
        [ P.map BucketRoute (P.s "bucket" </> P.string)
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        dismissDialog =
            case String.isEmpty model.api.dialog.title of
                True ->
                    Sub.none

                False ->
                    Events.onKeyUp <| escapeDecoder <| ApiMsg ClearDialog
    in
    Sub.batch
        [ loadMore LoadMore
        , dismissDialog
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "(Another) Williams College Course Catalog"
    , body =
        [ lazy viewDialog model.api.dialog
        , lazy viewNavbar model.api.currentUser
        , lazy2 viewToolbar model.api.searchTerm model.displayMode
        , viewCourses model
        ]
    }


viewNavbar : String -> Html Msg
viewNavbar currentUser =
    div [ id "navbar" ]
        [ div [ id "navbar-inner" ]
            [ h1 [ onClick GoToIndex ]
                [ span [ id "another" ] [ text "(ANOTHER)" ], text "CATALOG" ]
            , a [ href "/faq" ] [ text "FAQ" ]
            , span
                [ id "login"
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


viewToolbar : String -> DisplayMode -> Html Msg
viewToolbar searchTerm displayMode =
    let
        searchValue =
            case displayMode of
                Search ->
                    searchTerm

                _ ->
                    ""

        bucketText =
            case displayMode of
                Bucket ->
                    "View All"

                _ ->
                    "View Bucket"
    in
    div [ id "toolbar" ]
        [ form [ action "", onSubmit SubmitSearch ]
            [ input
                [ id "search"
                , type_ "text"
                , onInput UserSearch
                , placeholder "Search anything..."
                , value searchValue
                , autocomplete False
                , spellcheck False
                , attribute "autocorrect" "off"
                , attribute "autocapitalize" "none"
                ]
                []
            ]
        , div [ id "tool-buttons" ]
            [ viewTermSelection
            , viewToolbarButton ToggleBucket collections_bookmark bucketText
            , viewToolbarButton (ApiMsg ShowSaveBucket) save "Save bucket"
            , viewToolbarButton (ApiMsg ShowLoadBucket) collections "Go to bucket"
            ]
        ]


viewToolbarSelection : (String -> Msg) -> Icon -> List ( String, String ) -> Html Msg
viewToolbarSelection msg icon options =
    span [ class "tool-button" ]
        [ iconize icon
        , select [ onInput msg ] <|
            List.map (\( v, t ) -> option [ value v ] [ text t ]) options
        ]


viewTermSelection : Html Msg
viewTermSelection =
    viewToolbarSelection SelectTerm date_range <|
        [ ( "fall-2019", "Fall 2019" )
        , ( "spring-2020", "Spring 2020" )
        ]


viewToolbarButton : Msg -> Icon -> String -> Html Msg
viewToolbarButton msg icon content =
    span [ class "tool-button", onClick msg ] [ iconize icon, text content ]


viewCourses : Model -> Html Msg
viewCourses model =
    let
        courses =
            case model.displayMode of
                All ->
                    List.take (model.page * perPage) model.api.courses

                Search ->
                    List.take (model.searchPage * perPage) model.api.searchResults

                Bucket ->
                    List.filter
                        (\course -> Set.member course.id model.api.bucket)
                        model.api.courses
    in
    case courses of
        [] ->
            div [ id "courses" ] [ text "Nothing found! Are you in the right semester?" ]

        _ ->
            div [ id "courses" ] <|
                List.map
                    (\c ->
                        lazy4 viewCourse model.api.bucket model.expandedCourses model.api.details c
                    )
                    courses


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
            , ( "Pass / Fail Option", [ viewBool detail.passfail ] )
            , ( "Fifth Course Option", [ viewBool detail.fifthcourse ] )
            , ( "Divisions", detail.dreqs )
            , ( "Distributions", detail.divattr )
            , ( "Crosslistings", detail.xlistings )
            , ( "Writing Skills", [ detail.wsnotes ] )
            , ( "Difference, Power and Equity", [ detail.dpenotes ] )
            , ( "Quantitative / Formal Reasoning", [ detail.qfrnotes ] )
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


viewBool : Bool -> String
viewBool bool =
    if bool then
        "yes"

    else
        "no"


onLocalClick : Msg -> Html.Attribute Msg
onLocalClick msg =
    stopPropagationOn "click" <|
        D.map (\m -> ( m, True )) <|
            D.succeed msg


escapeDecoder : Msg -> D.Decoder Msg
escapeDecoder msg =
    let
        tagger key =
            case key of
                27 ->
                    msg

                _ ->
                    NoOp
    in
    D.map tagger keyCode


type alias Icon =
    Color -> Int -> Svg Msg


iconize : Icon -> Svg Msg
iconize icon =
    icon black 16
