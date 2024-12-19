library evaluate;

final List<String> letters =
    List.generate(26, (i) => String.fromCharCode(97 + i));
final Set<String> lettersSet = Set.from(letters);

List<TrieNode> recursiveCartesianProduct(
    int n, int depth, TrieNode dictionary) {
  if (depth == 0) {
    return [dictionary];
  }

  List<TrieNode> combinations = [];

  for (var letter in letters) {
    var temporaryDictionary = dictionary.walk(letter);

    if (temporaryDictionary == null) {
      continue;
    }

    if ((temporaryDictionary.childrenCount == 0 ||
            temporaryDictionary.isEndOfWord) &&
        depth > 1) {
      continue;
    }

    combinations
        .addAll(recursiveCartesianProduct(n, depth - 1, temporaryDictionary));
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
    int player, int playerCount, TrieNode dictionary, Map<String, int> game) {
  if (dictionary.childrenCount == 0) {
    return null;
  }

  if (dictionary.isEndOfWord) {
    return false;
  } else {
    Set<dynamic> chv = <dynamic>{};
    for (var letter in lettersSet) {
      var temporaryDictionary = dictionary.walk(letter);

      if (temporaryDictionary == null ||
          temporaryDictionary.childrenCount == 0 ||
          temporaryDictionary.isEndOfWord) {
        continue;
      }
      if (dictionary.currentLength % playerCount == player) {
        chv.add(evaluate(player, playerCount, temporaryDictionary, game));
      } else {
        int iterations = ((player % playerCount) -
                dictionary.currentLength % playerCount +
                playerCount) %
            playerCount; // This solves path.length + iterations % playerCount == player

        for (var combination in recursiveCartesianProduct(
            iterations - 1, iterations - 1, temporaryDictionary)) {
          chv.add(evaluate(player, playerCount, combination, game));
        }
      }
    }

    int answer = mex(chv);
    game[dictionary.currentWord] = answer;

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

// This is a slightly modified version of the trie implementation from retrieval (10x faster than the original evaluation, 6x overall)
class Trie {
  final root = TrieNode<void>(key: null, value: null);

  void insert(String word) {
    var currentNode = root;

    var characters = word.split("");

    for (int i = 0; i < characters.length; i++) {
      currentNode = currentNode.putChildIfAbsent(characters[i], value: null);
      currentNode.currentLength = i + 1;
      currentNode.currentWord = word.substring(0, i + 1);
    }

    currentNode.isEndOfWord = true;
  }

  bool has(String word) {
    return findPrefix(word, fromNode: root)?.isEndOfWord ?? false;
  }

  bool hasChildren(String word) {
    final prefix = findPrefix(word, fromNode: root);

    if (prefix == null) {
      return false;
    }

    return prefix.childrenCount > 0;
  }

  List<String> find(String prefix) {
    final lastCharacterNode = findPrefix(prefix, fromNode: root);

    if (lastCharacterNode == null) {
      return [];
    }

    final stack = <_PartialMatch>[
      _PartialMatch(node: lastCharacterNode, partialWord: prefix),
    ];
    final foundWords = <String>[];

    while (stack.isNotEmpty) {
      final partialMatch = stack.removeLast();

      if (partialMatch.node.isEndOfWord) {
        foundWords.add(partialMatch.partialWord);
      }

      for (final child in partialMatch.node.getChildren()) {
        stack.add(
          _PartialMatch(
            node: child,
            partialWord: "${partialMatch.partialWord}${child.key}",
          ),
        );
      }
    }

    return foundWords;
  }
}

class _PartialMatch {
  final TrieNode node;
  final String partialWord;

  _PartialMatch({
    required this.node,
    required this.partialWord,
  });

  @override
  String toString() => '_PartialMatch(node: $node, prefix: $partialWord)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is _PartialMatch &&
        other.node == node &&
        other.partialWord == partialWord;
  }

  @override
  int get hashCode => node.hashCode ^ partialWord.hashCode;
}

class TrieNode<T> {
  final String? key;

  T? value;

  int currentLength = 0;

  String currentWord = "";

  bool isEndOfWord = false;

  bool get isRoot => key == null;

  final Map<String, TrieNode<T>> _children = {};

  bool get hasChildren => _children.isEmpty;

  int get childrenCount => _children.length;

  TrieNode({required this.key, this.value});

  Iterable<TrieNode<T>> getChildren() {
    return _children.values;
  }

  bool hasChild(String key) {
    return _children.containsKey(key);
  }

  TrieNode<T>? getChild(String key) {
    return _children[key];
  }

  TrieNode<T> putChildIfAbsent(String key, {T? value}) {
    return _children.putIfAbsent(
      key,
      () => TrieNode<T>(key: key, value: value),
    );
  }

  TrieNode<T>? walk(String key) {
    return findPrefix(key, fromNode: this);
  }

  @override
  String toString() {
    return "TrieNode(key=$key, value=$value)";
  }
}

TrieNode<T>? findPrefix<T>(String prefix, {required TrieNode<T> fromNode}) {
  TrieNode<T>? currentNode = fromNode;

  for (final character in prefix.split("")) {
    currentNode = currentNode?.getChild(character);
    if (currentNode == null) {
      return null;
    }
  }

  return currentNode;
}
