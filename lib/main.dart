import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import "./algorithm.dart";
import "./data/frequency.dart";
import 'data/full_scrabble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      title: 'Ghost AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Ghost AI'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, int> gameData = {};
  Trie? dictionaryTrie;
  int player = 0;
  int playerCount = 2;
  String path = "";
  DictionaryType dictionaryType = DictionaryType.semiReasonableScrabble;
  bool isGenerating = false;
  Trie fullScrabbleTrie = Trie();

  @override
  void initState() {
    super.initState();
    generateGameFile();

    for (var word in scrabbleComplete) {
      fullScrabbleTrie.insert(word);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Dictionary type: "),
                    DropdownButton<DictionaryType>(
                        value: dictionaryType,
                        items: const [
                          DropdownMenuItem(
                            value: DictionaryType.semiReasonableScrabble,
                            child: Text("Semi-Reasonable Scrabble"),
                          ),
                          DropdownMenuItem(
                            value: DictionaryType.reasonableScrabble,
                            child: Text("Reasonable Scrabble"),
                          ),
                          DropdownMenuItem(
                            value: DictionaryType.fullScrabble,
                            child: Text("Full Scrabble"),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            dictionaryType = value;
                          });
                          generateGameFile();
                        }),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Player count: "),
                    DropdownButton<int>(
                      value: playerCount,
                      onChanged: (int? newValue) {
                        if (newValue == null) {
                          return;
                        }
                        setState(() {
                          if (newValue <= player) {
                            player = newValue - 1;
                          }
                          playerCount = newValue;
                        });
                        generateGameFile();
                      },
                      items: [2, 3, 4, 5, 6].map((index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text((index).toString()),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 32),
                    const Text("Player: "),
                    DropdownButton<int>(
                      value: player,
                      onChanged: (int? newValue) {
                        if (newValue == null) {
                          return;
                        }
                        setState(() {
                          player = newValue;
                        });
                        generateGameFile();
                      },
                      items: List.generate(playerCount, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text((index + 1).toString()),
                        );
                      }),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextField(
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: "Current path (i.e. ghos)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        path = value.toLowerCase();
                      });
                    },
                  ),
                ),
                if (isGenerating)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  )
                else if (gameData.isEmpty)
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
                    child: Text("Please choose which player you want to win.",
                        style: TextStyle(fontSize: 24),
                        textAlign: TextAlign.center),
                  )
                else
                  AlgorithmShower(
                    dictionaryTrie: dictionaryTrie!,
                    gameData: gameData,
                    player: player,
                    playerCount: playerCount,
                    path: path,
                    dictionaryType: dictionaryType,
                    fullScrabbleTrie: fullScrabbleTrie,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> generateGameFile() async {
    if (isGenerating) {
      await Future.doWhile(() =>
          Future.delayed(const Duration(milliseconds: 100))
              .then((_) => isGenerating));
    }

    setState(() {
      gameData = {};
      dictionaryTrie = null;
      isGenerating = true;
    });

    final receivePort = ReceivePort();

    final isolate =
        await Isolate.spawn<List<dynamic>>((List<dynamic> arguments) {
      SendPort sendPort = arguments[0];

      List<String> words = [];

      switch (arguments[3]) {
        case DictionaryType.semiReasonableScrabble:
          words = frequency.keys.toList();
          break;
        case DictionaryType.reasonableScrabble:
          List<String> frequencyList = frequency.keys.toList();
          frequencyList.sort((a, b) => frequency[b]!.compareTo(frequency[a]!));
          words = frequencyList.sublist(0, 10000);
          break;
        case DictionaryType.fullScrabble:
          words = scrabbleComplete;
          break;
      }

      Trie dictionary = Trie();
      for (var word in words) {
        dictionary.insert(word);
      }

      Map<String, int> game = {};

      evaluate(arguments[1], arguments[2], dictionary.root, game);

      sendPort.send([game, dictionary]);
    }, [receivePort.sendPort, player, playerCount, dictionaryType]);

    receivePort.listen((message) {
      setState(() {
        gameData = message[0];
        dictionaryTrie = message[1];
        isGenerating = false;
      });
      receivePort.close();
      isolate.kill();
    });
  }
}

class AlgorithmShower extends StatefulWidget {
  final Trie dictionaryTrie;
  final Map<String, int> gameData;
  final int player;
  final int playerCount;
  final String path;
  final DictionaryType dictionaryType;
  final Trie fullScrabbleTrie;

  const AlgorithmShower({
    Key? key,
    required this.dictionaryTrie,
    required this.gameData,
    required this.player,
    required this.playerCount,
    required this.path,
    required this.dictionaryType,
    required this.fullScrabbleTrie,
  }) : super(key: key);

  @override
  State<AlgorithmShower> createState() => _AlgorithmShowerState();
}

class _AlgorithmShowerState extends State<AlgorithmShower> {
  Future<List<dynamic>>? future;

  bool isTurn = false;
  Map<String, double> optimalGame = {};
  List<MapEntry<String, double>> sortedLetters = [];
  String? showWords;

  @override
  void initState() {
    super.initState();
    _initializeAlgorithm();
  }

  @override
  void didUpdateWidget(covariant AlgorithmShower oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.player != widget.player ||
        oldWidget.playerCount != widget.playerCount) {
      _initializeAlgorithm();
    }
  }

  void _initializeAlgorithm() {
    if (!widget.dictionaryTrie.hasChildren(widget.path) ||
        widget.dictionaryTrie.has(widget.path)) {
      return;
    }

    showWords = null;

    isTurn = widget.path.length % widget.playerCount == widget.player;

    optimalGame.clear();
    sortedLetters.clear();

    future = compute(determinePercentageIsolate, [
      widget.dictionaryTrie,
      widget.gameData,
      widget.playerCount,
      widget.path,
      isTurn,
    ]);
  }

  static List<dynamic> determinePercentageIsolate(List<dynamic> arguments) {
    var isTurn = arguments[4] as bool;

    if (!isTurn) {
      return [null, null];
    }

    var dictionaryTrie = arguments[0] as Trie;
    var gameData = arguments[1] as Map<String, int>;
    var playerCount = arguments[2] as int;
    var path = arguments[3] as String;

    var temporaryDictionary = dictionaryTrie.root.walk(path)!;

    var optimalGame = <String, double>{};
    var sortedLetters = <MapEntry<String, double>>[];

    for (var letter in letters) {
      if (!temporaryDictionary.hasChild(letter)) {
        continue;
      }
      optimalGame[letter] =
          determinePercentage(path + letter, gameData, playerCount);
    }

    sortedLetters.addAll(optimalGame.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));

    return [optimalGame, sortedLetters];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
        future: future,
        builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return const SizedBox();
            case ConnectionState.waiting:
              return primaryInterface(context, isLoading: true);
            case ConnectionState.active:
              return const SizedBox();
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Text("Error: ${snapshot.error}");
              }

              if (snapshot.data![0] != null) {
                optimalGame = snapshot.data![0] as Map<String, double>;
                sortedLetters =
                    snapshot.data![1] as List<MapEntry<String, double>>;
              }

              return primaryInterface(context);
          }
        });
  }

  RenderObjectWidget primaryInterface(BuildContext context,
      {bool isLoading = false}) {
    // Note: optimalGame and sortedLetters can **only** be used when loading is false.

    if (widget.dictionaryTrie.has(widget.path)) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Text(
          "The current path is a word.",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!widget.dictionaryTrie.hasChildren(widget.path)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            const Text(
              "Challenge! The current path contains no valid words.",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.fullScrabbleTrie.hasChildren(widget.path))
              const Text(
                "Note: Words exist in the full Scrabble dictionary. Change the dictionary type to view them.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }

    int iterations = ((widget.player % widget.playerCount) -
            widget.path.length % widget.playerCount +
            widget.playerCount) %
        widget
            .playerCount; // This solves path.length + iterations % playerCount == player (don't ask how I came up with this)

    String recommendedMove = "";

    if (isTurn && !isLoading) {
      final topFew = <String>[];
      for (var entry in sortedLetters) {
        if (entry.value == sortedLetters.first.value) {
          topFew.add(entry.key);
        } else {
          break;
        }
      }

      double bestFrequency = 0;

      for (var option in topFew) {
        List<double> frequencyList = [];

        for (var word in widget.dictionaryTrie.find(widget.path + option)) {
          if (!frequency.containsKey(word)) {
            frequencyList.add(0);
            continue;
          }
          frequencyList.add(frequency[word]!);
        }

        frequencyList.sort((a, b) => b.compareTo(a));

        // Warning: this is a **long** comment
        // A long time ago, I implemented the average of the all the frequencies.
        // However, I then realized that the average of the top few frequencies is more accurate.
        // Then I decided to implement a fancy algorithm to only check the words that you can win on.
        // Then I got lazy and decided to just check the first word.
        // Then I remembered the documentation for Beep from assembly code and thought that it would make a good remix-comment.
        // TODO: Implement fancy algorithm and remove the above comment
        double averageFrequency = frequencyList.isEmpty ? 0 : frequencyList[0];

        if (averageFrequency > bestFrequency) {
          bestFrequency = averageFrequency;
          recommendedMove = option;
        }
      }
    }

    List<MapEntry<String, int>>? winningOutcomes;

    if (!isTurn) {
      winningOutcomes = widget.gameData.entries
          .where((entry) =>
              entry.key.startsWith(widget.path) &&
              entry.value > 0 &&
              entry.key.length == widget.path.length + iterations)
          .toList();
      winningOutcomes.addAll(widget.dictionaryTrie
          .find(widget.path)
          .where((element) => element.length <= widget.path.length + iterations)
          .map((e) => MapEntry(e, 1)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        if (isTurn && (recommendedMove != "" || isLoading))
          const Text(
            "Recommended move:",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
          ),
        if (isTurn && recommendedMove != "" && !isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  recommendedMove,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (showWords != widget.path + recommendedMove) {
                          showWords = widget.path + recommendedMove;
                        } else {
                          showWords = null;
                        }
                      });
                    },
                    style: showWords == widget.path + recommendedMove
                        ? ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.tertiaryContainer,
                          )
                        : null,
                    child: Text(
                      "${showWords == widget.path + recommendedMove ? "Hide" : "View"} Words",
                      style: showWords == widget.path + recommendedMove
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.tertiary)
                          : null,
                    )),
              ],
            ),
          ),
        if (isTurn && isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: CircularProgressIndicator(),
          ),
        if (isTurn && (recommendedMove != "" || isLoading))
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              "Note: The recommended move is based on the percentage of winning and the average frequency of words that can be formed.",
              textAlign: TextAlign.center,
            ),
          ),
        if (isTurn)
          const Text(
            "The best moves are:",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
          ),
        if (!isTurn)
          const Text(
            "It's not your turn.",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
          )
        else if (!isLoading)
          SizedBox(
            height: 256,
            child: SingleChildScrollView(
              child: Column(
                  children: sortedLetters.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "at ${(entry.value * 100).toStringAsFixed(1)}% chance",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (showWords != widget.path + entry.key) {
                                showWords = widget.path + entry.key;
                              } else {
                                showWords = null;
                              }
                            });
                          },
                          style: showWords == widget.path + entry.key
                              ? ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .tertiaryContainer,
                                )
                              : null,
                          child: Text(
                            "${showWords == widget.path + entry.key ? "Hide" : "View"} Words",
                            style: showWords == widget.path + entry.key
                                ? TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.tertiary)
                                : null,
                          )),
                    ],
                  ),
                );
              }).toList()),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: (256 - 128) / 2),
            child: SizedBox(
              height: 128,
              width: 128,
              child: CircularProgressIndicator(),
            ),
          ),
        if (isTurn)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              "Note: The percentage is assuming that the turn comes back to you. It is possible to win with 0% if someone spells a word before you get to play next.",
              textAlign: TextAlign.center,
            ),
          ),
        if (!isTurn)
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 28, 8, 0),
            child: Text(
                "You would win if your opponents follow one of these paths or spell a word:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
        if (!isTurn && !isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              winningOutcomes!.isNotEmpty
                  ? winningOutcomes.map((entry) => entry.key).join(", ")
                  : "You can't win unless if your opponent spells a word",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300),
              textAlign: TextAlign.center,
            ),
          ),
        if (!isTurn && isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        if (!isTurn)
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 28, 8, 0),
            child: Text(
                "You would lose if your opponents follow one of these paths:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
        if (!isTurn && !isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              widget.gameData.entries
                      .where((entry) =>
                          entry.key.startsWith(widget.path) &&
                          entry.value == 0 &&
                          entry.key.length == widget.path.length + iterations)
                      .isNotEmpty
                  ? widget.gameData.entries
                      .where((entry) =>
                          entry.key.startsWith(widget.path) &&
                          entry.value == 0 &&
                          entry.key.length == widget.path.length + iterations)
                      .map((entry) => entry.key)
                      .join(", ")
                  : "You can't lose",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300),
              textAlign: TextAlign.center,
            ),
          ),
        if (!isTurn && isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        if (!isTurn)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (showWords != widget.path) {
                      showWords = widget.path;
                    } else {
                      showWords = null;
                    }
                  });
                },
                style: showWords == widget.path
                    ? ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.tertiaryContainer,
                      )
                    : null,
                child: Text(
                  "${showWords == widget.path ? "Hide" : "View"} Words",
                  style: showWords == widget.path
                      ? TextStyle(color: Theme.of(context).colorScheme.tertiary)
                      : null,
                )),
          ),
        if (showWords != null)
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "Words that can be formed:",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
            ),
          ),
        if (showWords != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 5.0, horizontal: 16.0),
            child: SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      () {
                        List<String> words =
                            widget.dictionaryTrie.find(showWords!);
                        words.sort((a, b) =>
                            (frequency[b] ?? 0).compareTo(frequency[a] ?? 0));
                        return words
                            .sublist(
                                0,
                                min(
                                    widget.dictionaryTrie
                                        .find(showWords!)
                                        .length,
                                    128))
                            .join(", ");
                      }(), // Don't ask
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

enum DictionaryType { semiReasonableScrabble, fullScrabble, reasonableScrabble }
