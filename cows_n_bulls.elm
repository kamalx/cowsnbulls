import Char
import Html exposing (a, Attribute, button, div, footer, header, Html, input, img, text)
import Html.Attributes as Attr
        exposing (autofocus, href, id, maxlength, name, placeholder, src, style, target, value)
import Html.Events exposing (keyCode, on, onClick, targetValue)
import Html.Lazy exposing (lazy2)
import Http
import Json.Decode as Json
import List
import Maybe
import Random
import Set
import Signal exposing ((<~), Signal, Address)
import String
import Task exposing (andThen, Task, toMaybe)
import Time exposing (every, millisecond)

-- MODEL

type Message = DownloadMessage | GuessMessage | ErrorMessage | NoWordListMessage

showMessage : Message -> String
showMessage message =
    case message of
      DownloadMessage -> "Wait, Downloading word list..."
      NoWordListMessage -> "Failed to download word list."
      GuessMessage -> "Guess a 4-letter word."
      ErrorMessage -> "Only 'valid' 4-letter, without repetition! Should we add word to our list?"

type alias Model =
    { word: String
    , input: String
    , guess: String
    , result: (Int, Int)
    , words: List String
    , guess_count: Int
    , guessed: Bool
    , message: Message
    }

emptyModel = { word = ""
             , input = ""
             , guess=""
             , guess_count = 0
             , result = (0, 0)
             , words = []
             , guessed = False
             , message = DownloadMessage
             }

-- UPDATE

type Action = NoOp
            | Guess
            | UpdateInput String
            | UpdateWords (List String)
            | PickWord Random.Seed
            | ShowWord
            | NoWordList Bool

update : Action -> Model -> Model
update action model =
    case action of
      NoOp -> model

      UpdateInput str ->
        { model |
                  input <- str,
                  guess <- "",
                  guessed <- False
         }

      Guess ->
          let valid = validWord model.words model.input
          in
            if valid
            then { model |
                           guess <- model.input,
                           result <- checkGuess model.word model.input,
                           input <- "",
                           guess_count <- model.guess_count + 1,
                           guessed <- model.input == model.word,
                           message <- GuessMessage
                 }
            else { model |
                           input <- "",
                           message <- ErrorMessage
                 }

      UpdateWords words ->
          { emptyModel |
                         words <- words
          }

      NoWordList _ ->
          { emptyModel |
                         message <- NoWordListMessage
          }

      ShowWord ->
          {
            emptyModel |
                         guessed <- True,
                         words <- model.words,
                         word <- model.word
          }

      PickWord seed ->
          { emptyModel |
                         word <- getRandomItem seed model.words |> Maybe.withDefault "",
                         words <- model.words,
                         message <- GuessMessage
          }

-- VIEW

view : Address Action -> Model -> Html
view address model =
    let
        restart_button =
            button
            [ onClick pickWord.address 1 ]
            [ text "Restart" ]

        dict_div =
            div
            [ inputStyle ]
            [ ( a
                [ href ("http://www.dict.org/bin/Dict?Form=Dict2&Database=*&Query=" ++ model.word)
                , target "_blank"
                ]
                [ text <| "See meaning: " ++ model.word ]
              ),
              div [] [restart_button]
            ]

        show_result =
            \(bulls, cows) -> toString bulls ++ " bulls, " ++ toString cows ++ " cows"

        result =
            div [inputStyle] [ text <|
                                    if (model.guess == "" || model.guessed)
                                    then ""
                                    else (show_result model.result) ++ " in \"" ++ model.guess ++ "\""
                             ]
        guessed = if (model.guessed && model.guess_count > 0)
                  then "Hooray! Guessed '" ++ model.word ++ "' in "
                  else ""

        guess_count = guessed ++ if model.guess_count > 0
                                 then toString model.guess_count ++
                                      if model.guess_count == 1 then " guess" else " guesses"
                                 else ""

        tweet = if not (guessed == "")
                then ( a
                       [ href ("https://twitter.com/home?status=" ++ guess_count ++ " at cowsnbulls.in")
                       , target "_blank"
                       ]
                       [ img
                         [src "https://cdn3.iconfinder.com/data/icons/rcons-social/32/bird_twitter-32.png"]
                         []
                       ]
                     )
                else a [] []

    in
      div
      []
      [ siteHeader
      , if model.guessed then dict_div else lazy2 guessWord address model
      , result
      , div [inputStyle] [ text <| guess_count, div [] [tweet] ]
      , button
        [ onClick address ShowWord
        , if (model.guess_count > 0 && not model.guessed) then restartStyle else hideStyle
        ]
        [ text "Give up" ]
      , siteFooter
      ]

onEnter : Address a -> a -> Attribute
onEnter address value =
    on "keydown"
      (Json.customDecoder keyCode is13)
      (\_ -> Signal.message address value)


is13 : Int -> Result String ()
is13 code =
  if code == 13 then Ok () else Err "not the right key code"

guessWord : Address Action -> Model -> Html
guessWord address model =
      input
        [ id "guess"
        , placeholder <| showMessage model.message
        , maxlength 4
        , autofocus True
        , value model.input
        , name "guess"
        , on "input" targetValue (Signal.message address << UpdateInput)
        , onEnter address Guess
        , inputStyle
        ]
        []


siteFooter : Html
siteFooter = footer
             [ footerStyle ]
             [ ( a
                [ href ("https://github.com/punchagan/cowsnbulls")
                , target "_blank"
                ]
                [ text <| "Built" ]
               )
             , text " with 💔 in Bangalore. In memory of the best cows & bulls player I've known."
             ]

siteHeader : Html
siteHeader = header [ headerStyle ] [ text "Tell me you're free. I wanna play Cows & Bulls!" ]


-- STYLES

inputStyle : Attribute
inputStyle =
  style
    [ ("width", "100%")
    , ("height", "40px")
    , ("padding", "10px 0")
    , ("font-size", "2em")
    , ("text-align", "center")
    ]

restartStyle : Attribute
restartStyle =
  style
  [ ("height", "40px")
  , ("padding", "10px")
  , ("margin-left", "48%")
  , ("font-size", "1em")
  , ("text-align", "center")
  ]

hideStyle : Attribute
hideStyle =
  style
  [ ("display", "None") ]

footerStyle : Attribute
footerStyle =
  style
    [ ("width", "100%")
    , ("padding", "10px 0")
    , ("font-size", "1em")
    , ("opacity", "0.5")
    , ("text-align", "center")
    , ("position", "absolute")
    , ("bottom", "0px")
    , ("border-top", "solid gray 1px")
    ]

headerStyle : Attribute
headerStyle =
  style
    [ ("width", "100%")
    , ("padding", "10px 0")
    , ("font-size", "2.25em")
    , ("opacity", "0.6")
    , ("text-align", "center")
    , ("top", "0px")
    ]

-- SIGNALS

main : Signal Html
main =
  Signal.map (view actions.address) model

-- manage the model of our application over time
model : Signal Model
model =
  Signal.foldp update emptyModel updateEvents

wordDb : Signal.Mailbox (List String)
wordDb =
    Signal.mailbox []

clockSeed : Signal Random.Seed
clockSeed = (\time -> Random.initialSeed (round time)) <~ (every millisecond)

pickWord : Signal.Mailbox Int
pickWord =
    Signal.mailbox 1

noWordList : Signal.Mailbox Bool
noWordList =
    Signal.mailbox False

updateWords : (Maybe String) -> Task x ()
updateWords content =
    case content of
      Maybe.Nothing ->
          Signal.send noWordList.address True
      Maybe.Just s ->
          (Signal.send wordDb.address (s |> String.trim |> String.lines))
          `andThen` \_ -> (Signal.send pickWord.address 1)


port getWords : Task Http.Error ()
port getWords =
    let
        url = "word_list.txt"
    in
      toMaybe (Http.getString url)
              `andThen` updateWords

-- actions from user input
actions : Signal.Mailbox Action
actions =
    Signal.mailbox NoOp

updateEvents : Signal Action
updateEvents =
    Signal.mergeMany [
               actions.signal,
               Signal.map UpdateWords wordDb.signal,
               Signal.map PickWord (Signal.sampleOn pickWord.signal clockSeed),
               Signal.map NoWordList noWordList.signal
              ]

-- HELPERS

checkGuess : String -> String -> (Int, Int)
checkGuess word guess =
    let guess_set = String.toList guess |> Set.fromList
        word_set = String.toList word |> Set.fromList
        total = Set.intersect word_set guess_set |> Set.toList |> List.length
        bulls = String.filter (\x -> let y = String.fromChar x in String.indexes y word == String.indexes y guess) guess |> String.length
    in (bulls, total - bulls)

validWord : (List String) -> String -> Bool
validWord words guess =
    List.member guess words

getRandomItem : Random.Seed -> List a -> Maybe a
getRandomItem seed xs =
    let n = List.length xs
        (m, _) = Random.generate (Random.int 0 n) seed
    in
      List.head <| List.drop m xs
