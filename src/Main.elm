-- Read more about this program in the official Elm guide:
-- https://guide.elm-lang.org/architecture/effects/random.html


module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (decodeUri, encodeUri)
import Json.Decode exposing (decodeString, float, list)
import Maybe exposing (..)
import Navigation
import Net
import Src.NetSvg exposing (display)
import Time exposing (Time, millisecond)
import UrlParser as Url exposing ((</>), (<?>), int, s, string, stringParam, top)


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias ParamsMap =
    { inputs : String, targets : String }


type Route
    = Params String String (Maybe String) (Maybe String) -- needs the string at the beginning due to elm-reactor


routeFunc : Url.Parser (Route -> a) a
routeFunc =
    Url.oneOf
        [ Url.map Params (string </> string <?> stringParam "inputs" <?> stringParam "targets")
        ]



-- MODEL


type alias Model =
    { net : Net.Net
    , tests : List ( List String, List String )
    , inputs : Int
    , hiddens : Int
    , outputs : Int
    , backpropIter : Int
    , running : Bool
    }



--inputs [[0, 0], [1, 0], [0, 1], [1, 1]]
--targets [[0], [1], [1], [0]]


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        params =
            routeParser (Url.parsePath routeFunc location)

        tests =
            List.map2 (,) (stringToList params.inputs) (stringToList params.targets)

        inputSize =
            getSizeOfNestedList params.inputs

        outputSize =
            getSizeOfNestedList params.targets
    in
    ( Model (Net.createNetDeterministic inputSize inputSize outputSize 624334567345) tests inputSize inputSize outputSize 1000 False
    , Net.createNetRandom inputSize inputSize outputSize NewNet
    )


routeParser : Maybe Route -> ParamsMap
routeParser route =
    let
        defaultParams =
            { inputs = "[[\"0\",\"0\"],[\"1\",\"0\"],[\"0\",\"1\"],[\"1\",\"1\"]]", targets = "[[\"0\"],[\"1\"],[\"1\"],[\"0\"]]" }
    in
    case route of
        Just params ->
            case params of
                Params str1 str2 maybeInputs maybeTargets ->
                    { inputs = maybeUri defaultParams.inputs maybeInputs, targets = maybeUri defaultParams.targets maybeTargets }

        Nothing ->
            defaultParams


maybeUri : String -> Maybe String -> String
maybeUri default maybe =
    case maybe of
        Just uri ->
            withDefault default (decodeUri uri)

        Nothing ->
            default



-- UPDATE


type Msg
    = Randomize
    | NewNet Net.Net
    | TimedBackprop Time
    | NewBackprop String
    | UrlChange Navigation.Location
    | IncInput
    | DecInput
    | IncHidden
    | DecHidden
    | IncOutput
    | DecOutput
    | ChangeTest Int NodeType Int String
    | ToggleRunning
    | AddTest
    | RemoveTest Int


type NodeType
    = Input
    | Hidden
    | Output


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Randomize ->
            ( model, Net.createNetRandom model.inputs model.hiddens model.outputs NewNet )

        NewNet newNet ->
            ( { model | net = newNet }, Cmd.none )

        TimedBackprop time ->
            let
                tests =
                    testsToTrainingSets model.tests
            in
            if model.running then
                ( { model | net = Net.backpropagateSet model.net 0.5 tests 1 }
                , Cmd.none
                )
            else
                ( model, Cmd.none )

        NewBackprop str ->
            let
                iter =
                    Result.withDefault 0 (String.toInt str)
            in
            ( { model | backpropIter = iter }, Cmd.none )

        UrlChange _ ->
            ( model, Cmd.none )

        IncInput ->
            ( { model
                | inputs = model.inputs + 1
                , tests = List.map (\( input, output ) -> ( List.append input [ "0" ], output )) model.tests
              }
            , Net.createNetRandom (model.inputs + 1) model.hiddens model.outputs NewNet
            )

        DecInput ->
            let
                newNum =
                    model.inputs - 1

                finalNum =
                    if newNum < 1 then
                        1
                    else
                        newNum

                tests =
                    if newNum < 1 then
                        model.tests
                    else
                        List.map (\( input, output ) -> ( pop input, output )) model.tests
            in
            ( { model
                | inputs = finalNum
                , tests = tests
              }
            , Net.createNetRandom finalNum model.hiddens model.outputs NewNet
            )

        IncHidden ->
            ( { model
                | hiddens = model.hiddens + 1
              }
            , Net.createNetRandom model.inputs (model.hiddens + 1) model.outputs NewNet
            )

        DecHidden ->
            let
                newNum =
                    model.hiddens - 1

                finalNum =
                    if newNum < 1 then
                        1
                    else
                        newNum
            in
            ( { model
                | hiddens = finalNum
              }
            , Net.createNetRandom model.inputs finalNum model.outputs NewNet
            )

        IncOutput ->
            ( { model
                | outputs = model.outputs + 1
                , tests = List.map (\( input, output ) -> ( input, List.append output [ "0" ] )) model.tests
              }
            , Net.createNetRandom model.inputs model.hiddens (model.outputs + 1) NewNet
            )

        DecOutput ->
            let
                newNum =
                    model.outputs - 1

                finalNum =
                    if newNum < 1 then
                        1
                    else
                        newNum

                tests =
                    if newNum < 1 then
                        model.tests
                    else
                        List.map (\( input, output ) -> ( input, pop output )) model.tests
            in
            ( { model
                | outputs = finalNum
                , tests = tests
              }
            , Net.createNetRandom model.inputs model.hiddens finalNum NewNet
            )

        ChangeTest testIndex nodeType nodeIndex str ->
            let
                tests =
                    List.indexedMap
                        (\index test ->
                            if index == testIndex then
                                case nodeType of
                                    Input ->
                                        ( List.indexedMap
                                            (\index node ->
                                                if index == nodeIndex then
                                                    str
                                                else
                                                    node
                                            )
                                            (Tuple.first test)
                                        , Tuple.second test
                                        )

                                    Hidden ->
                                        test

                                    Output ->
                                        ( Tuple.first test
                                        , List.indexedMap
                                            (\index node ->
                                                if index == nodeIndex then
                                                    str
                                                else
                                                    node
                                            )
                                            (Tuple.second test)
                                        )
                            else
                                test
                        )
                        model.tests
            in
            ( { model | tests = tests }, Cmd.none )

        ToggleRunning ->
            ( { model | running = not model.running }, Cmd.none )

        AddTest ->
            ( { model
                | tests = List.append model.tests [ ( List.repeat model.inputs "0", List.repeat model.outputs "0" ) ]
              }
            , Cmd.none
            )

        RemoveTest index ->
            ( { model
                | tests =
                    List.filterMap
                        (\( i, test ) ->
                            if i /= index then
                                Just test
                            else
                                Nothing
                        )
                        (List.indexedMap (,) model.tests)
              }
            , Cmd.none
            )


pop : List a -> List a
pop ls =
    List.take (List.length ls - 1) ls


stringToList : String -> List (List String)
stringToList str =
    case decodeString (Json.Decode.list (Json.Decode.list Json.Decode.string)) str of
        Ok ls ->
            ls

        Err _ ->
            [ [] ]


testsToTrainingSets : List ( List String, List String ) -> List Net.TrainingSet
testsToTrainingSets test =
    List.map
        (\( input, output ) ->
            Net.TrainingSet (testToFloat input) (testToFloat output)
        )
        test


testToFloat : List String -> List Float
testToFloat test =
    List.map (\s -> Result.withDefault 0 (String.toFloat s)) test


getSizeOfNestedList : String -> Int
getSizeOfNestedList str =
    let
        total =
            stringToList str
    in
    case List.head total of
        Just ls ->
            List.length ls

        Nothing ->
            0



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every millisecond TimedBackprop



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ class "container"
        ]
        [ controlPanel model
        , netDisplayPanel model
        ]


controlPanel : Model -> Html Msg
controlPanel model =
    div
        [ class "control-panel"
        ]
        [ div [ class "big-button", onClick Randomize ] [ text "Randomize" ]
        , netDimensions model
        , createTests model
        , div [ class "big-button", onClick ToggleRunning ]
            [ text
                (if model.running then
                    "Pause"
                 else
                    "Start"
                )
            ]
        ]


netDisplayPanel : Model -> Html Msg
netDisplayPanel model =
    div [ class "display" ]
        [ display model.net ]


netDimensions : Model -> Html Msg
netDimensions model =
    div
        [ class "net-dimens" ]
        [ netDimension "Inputs" model.inputs IncInput DecInput
        , netDimension "Hiddens" model.hiddens IncHidden DecHidden
        , netDimension "Outputs" model.outputs IncOutput DecOutput
        ]


netDimension : String -> Int -> Msg -> Msg -> Html Msg
netDimension label current incMsg decMsg =
    div
        [ class "dimen" ]
        [ div [] [ text label ]
        , div
            [ class "pill" ]
            [ div
                [ onClick incMsg
                , class "control"
                ]
                [ text "+" ]
            , div
                [ class "panel"
                ]
                [ text (toString current) ]
            , div
                [ onClick decMsg
                , class "control"
                ]
                [ text "-" ]
            ]
        ]


createTests : Model -> Html Msg
createTests model =
    div []
        (List.append
            (List.indexedMap (\index test -> createTest model index test) model.tests)
            [ div [ class "add-test", onClick AddTest ] [ text "+" ] ]
        )


createTest : Model -> Int -> ( List String, List String ) -> Html Msg
createTest model testIndex test =
    div [ class "test-case" ]
        [ div [ class "remove-test", onClick (RemoveTest testIndex) ] [ text "-" ]
        , div [ class "test-info" ]
            [ div [ class "test-inputs" ]
                (List.indexedMap
                    (\nodeIndex input -> createTestInput model testIndex Input nodeIndex input)
                    (Tuple.first test)
                )
            , div [ class "test-inputs" ] [ text "↓" ]
            , div [ class "test-inputs" ]
                (List.indexedMap
                    (\nodeIndex ( input, result ) -> createTestInputForOutput model testIndex Output nodeIndex input result)
                    (List.map2
                        (,)
                        (Tuple.second test)
                        (Net.forwardPass model.net (testToFloat (Tuple.first test)))
                    )
                )
            ]
        ]


createTestInput : Model -> Int -> NodeType -> Int -> String -> Html Msg
createTestInput model testIndex nodeType nodeIndex val =
    input [ class "test-input", onInput (ChangeTest testIndex nodeType nodeIndex), value val ] []


createTestInputForOutput : Model -> Int -> NodeType -> Int -> String -> Float -> Html Msg
createTestInputForOutput model testIndex nodeType nodeIndex val resultVal =
    div [ class "output-combo" ]
        [ createTestInput model testIndex nodeType nodeIndex val
        , div [] [ text (String.left 3 (toString (toFloat (round (resultVal * 10)) / 10))) ]
        ]
