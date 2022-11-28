# Salty Trivia with Candy Barre

Salty Trivia is a trivia game where the questions are ridiculous, but the answers are serious. It can be played locally, or online using a normal Web browser (like Jackbox games).

The game is written on Godot Engine (a free and open source game engine), and implements a mix of features from You Don't Know Jack 2015, You Don't Know Jack: Full Stream, and several other You Don't Know Jack entries.

## Features

Instead of the Screw from the You Don't Know Jack series, this game implements an item called the **Lifesaver**, which acts similarly to the 50/50 in *Who Wants to Be a Millionaire?*, in that it eliminates two of the choices for yourself. It can be used once per player per game, except in question types that are not multiple-choice.

* **Normal** - A standard 4-choice question.
* **Candy Trivia with Salty Barre** - A 4-choice question where the question is related to candy, or it's linked to a dumb joke on a candy wrapper. Analogous to Cookie's Fortune Cookie Fortunes with Cookie "Fortune Cookie" Masterson from the 2011 series.
* **Rage Against the Times with Ozzy** - A 4-choice question where the question is presented as a skit with "Ozzy, our 'resident' Australian squatter" who is an old man who is angry about one thing or another. Analogous to Foggy Facts with Old Man from 2015, except our Old Man is way grumpier.
* **Sorta Kinda** - A quick-fire round where 7 items each have to be sorted into two categories (sometimes both). Basically DisOrDat with a different name.
* **All Outta Salt** - Given a category and a nonsense phrase, find the phrase with syllables that rhyme with it. (e.g. With the category "With what proper name does this rhyme?" and the nonsense phrase "Forge bubble the tush.", the answer would be "George W. Bush".) Basically a Gibberish Question.
* **The Thousand-Question Question** - A special question type where the prize money starts out at $1,000,000, but since the host takes time to read the whole question text, by the time you're allowed to buzz in, the prize money dwindles down to about $2,000 at best. First-come first-served; only one person can get the prize money. Inspired by The Two-Million-Dollar Question from the short-lived ABC TV show. The Lifesaver cannot be used on this question type, despite being a 4-choice question.
* **Sugar Rush** - A final round containing 6 phases with 6 options. Given the overall topic and the condition given each phase, each option must be selected or left alone; each correct inclusion or omission is rewarded, and each incorrect one is punished. Similar to Full Stream's Jack Attack, but with no time bonuses, scored more similarly to Trivia Murder Party's final round, and with only 6 phases instead of 7.
* **Like It or Leave It** - A final round containing 5 phases with 4 options each, the first 3 of which stay throughout the phases. Given the overall topic and the condition given each phase, each option must be selected or left alone; each correct inclusion or omission is rewarded, and each incorrect one is punished. Similar to Trivia Murder Party's final round, except for the gimmick that 3 of the options stay throughout the question, but the last option changes every phase.

## How to Play

The current public build is published on [the Gotm webpage](https://gotm.io/haitouch/salty-trivia). Note that this version may not be the latest version with the latest features and question packs.

## How to Develop a Fork

1. Install the Godot Engine from the [official website](https://godotengine.org). As of writing this Readme file, the version used is 3.5 (non-Mono).

2. Download or fork the repository, and open the folder once you've booted Godot.

## How to Make Your Own Questions, Episodes, and Controller for a Fork

To use your own **question files**, use [the `salty_data` repository](https://github.com/JapanYoshi/salty_data) as a template. I don't recommend downloading the entire thing because it has hella WAV files and it takes space; just get everything except for the `/q/` folder, and follow the tutorial on that repository.

To make your own **episodes**, go to [the `/ep/` folder](https://github.com/JapanYoshi/salty/tree/main/ep). You will need to do two things:

* 1. Create a folder named as the ID of the episode.

* 2. Add the ID to `list.txt`, which is the list of episodes to display in the episode select screen.

* 3. Within the episode folder, change the contents of `ep.json` to list the question IDs to use, and any non-random voice lines to play. Non-random voice lines must be stored within the episode folder as well.

To use a different **phones-as-controller app and server**, fork [this other GitHub repository](https://github.com/JapanYoshi/haitouch-firebase) and host it on your Firebase instance.

You will need to set up your own instance of Firebase Realtime Database and Firebase Web Hosting, and change `const firebaseConfig` within `public/index.html` to make it connect to your database and not mine. Similarly, you will need to change `const firebase_config` within [`FirebaseManager.gd`](https://github.com/JapanYoshi/salty/tree/main/FirebaseManager.gd). To get the Firebase configuration data, please follow [this official “Add Firebase to your JavaScript project” tutorial from Firebase](https://firebase.google.com/docs/web/setup).

## Control schemes

This game supports 4 different control schemes.

### Keyboard

Up to 4 players can control the game on a normal keyboard with a numpad, each player using a matrix of 6 keys. Assuming the keyboard layout to be US ANSI QWERTY, Player 1 uses QWE/ASD, Player 2 uses FGH/VBN, Player 3 uses UIO/JKL, and Player 4 uses 789/456 on the Numeric Keypad.

### Gamepad

A standard Xbox 360-compatible gamepad can be used for up to 2 players.

When the player uses the whole controller, options are chosen with the ABXY buttons, and LB and RB are used for special purposes. The left stick is used for typing. This mode is compatible with most controllers.

When 2 players share the same controller, the left player chooses options with the D-Pad, and LT and LB are used for the L and R buttons, respectively. The left stick is used for typing. The right player chooses options with the ABXY buttons, and RB and RT are used for the L and R buttons, respectively. The right stick is used for typing.

#### Typing

This game involves some questions with free-response answers. There are 3 typing styles available:

* DaisyWheel - Based on a now-removed Steam Big Picture Mode feature. The joystick chooses between 9 pages of characters and each face button types in a different key. The fastest system once learned, but relatively difficult to get used to.

Note to localizers: Also requires multiple pages to use for any alphabet with more than 32 letters (such as Russian with 33 letters), and can only type a grand total of 64 different letters.

* Spiral - Swirl the joystick to seek forward and backward in the list of letters, and any face button types in the currently selected key. Moderately fast and easy to learn, but not as fast as DaisyWheel.

Note to localizers: You can expand this to support any number of letters, but there should be an exact multiple of 8 keys, including the copies of the `space` key after every loop.

* Grid - The old-fashioned method where the joystick is used to move the cursor on an old-fashioned gridwise table of letters. The slowest to type, but probably a method we've all used before.

Note to localizers: You will have to manually tweak a lot of stuff to change the number of keys. First, inside `TypingHandler.tscn`, you have to set `config.KB_WIDTH` and `config.KB_HEIGHT` to the desired grid size in the script `TypingHandler.gd`, and duplicate exactly `config.KB_WIDTH * config.KB_WEIGHT - 4` copies of the key element inside `$KB/Grid`. You must now manually resize and reposition the Space and Submit keys, since they are not part of the grid, as well as the gamepad shortcut labels for Space, Submit, and Delete. Then and only then can you edit the variable `config.kb_main` to contain the character to input.

### "Phones as Controllers"

A standard Web browser can be used to play the game by accessing [the hai!touch Controller webpage](https://haitouch.onrender.com). Its code is maintained in [this other GitHub repository](https://github.com/JapanYoshi/haitouch-heroku).

As an improvement to the official You Don't Know Jack games, the full question text and options text are displayed on the device, as well as the correctness of your choices.

If the player slots are full, or the game has already started, extra players can connect to a game as audience members and play along using the controller app.

### Touchscreen/Mouse

Since this game also runs on phones, you can also play the game solo using the mouse cursor.
