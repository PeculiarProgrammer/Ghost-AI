library evaluate;

import 'package:retrieval/trie.dart';

final List<String> letters =
    List.generate(26, (i) => String.fromCharCode(97 + i));
final Set<String> lettersSet = Set.from(letters);

List<String> recursiveCartesianProduct(
    String path, int n, int depth, Trie dictionary) {
  if (depth == 0) {
    return [path];
  }

  List<String> combinations = [];

  for (var letter in letters) {
    if ((dictionary.find(path + letter).isEmpty ||
            dictionary.has(path + letter)) &&
        depth > 1) {
      continue;
    }

    combinations.addAll(
        recursiveCartesianProduct(path + letter, n, depth - 1, dictionary));
  }

  return combinations;
}

int mex(Set<dynamic> s) {
  int i = 0;
  while (s.contains(i)) {
    i++;
  }
  return i;
}

dynamic evaluate(
    int player, int playerCount, Trie dictionary, Map<String, int> game,
    {String path = ""}) {
  if (dictionary.find(path).isEmpty) {
    return null;
  }

  if (dictionary.has(path)) {
    return false;
  } else {
    Set<dynamic> chv = <dynamic>{};
    for (var letter in lettersSet) {
      if (dictionary.find(path + letter).isEmpty ||
          dictionary.has(path + letter)) {
        continue;
      }
      if (path.length % playerCount == player) {
        chv.add(evaluate(player, playerCount, dictionary, game,
            path: path + letter));
      } else {
        int iterations = ((player % playerCount) -
                path.length % playerCount +
                playerCount) %
            playerCount; // This solves path.length + iterations % playerCount == player

        for (var combination in recursiveCartesianProduct(
            path + letter, iterations - 1, iterations - 1, dictionary)) {
          chv.add(evaluate(player, playerCount, dictionary, game,
              path: combination));
        }
      }
    }
    int answer = mex(chv);
    game[path] = answer;

    return answer;
  }
}

double determinePercentage(
    String path, Map<String, int> game, int playerCount) {
  if (game.containsKey(path) && game[path] == 0) {
    return 1.0;
  }

  int count = 0;
  int good = 0;

  for (var entry in game.entries) {
    if (entry.key.startsWith(path) &&
        entry.key.length == path.length + playerCount - 1 &&
        entry.value >= 0) {
      count += 1;
      if (entry.value >= 1) {
        good += 1;
      }
    }
  }

  if (count == 0) {
    return 0.0;
  }

  return good / count;
}
