import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'block.dart';
import 'sub_block.dart';

enum Collision { LANDED, LANDED_BLOCK, HIT_WALL, HIT_BLOCK, NONE }

const BLOCKS_X = 10;
const BLOCKS_Y = 20;
const REFRESH_RATE = 300;
const GAME_AREA_BORDER_WIDTH = 2.0;
const SUB_BLOCK_EDGE_WIDTH = 2.0;

class Game extends StatefulWidget {
  Game({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GameState();
}

class GameState extends State<Game> {
  bool isGameOver = false;
  double subBlockWidth;
  Duration duration = Duration(milliseconds: REFRESH_RATE);

  GlobalKey _keyGameArea = GlobalKey();

  BlockMovement action;
  Block block;
  Timer timer;
  bool isPlaying = false;
  int score;

  List<SubBlock> oldSubBlocks;

  Block getNewBlock() {
    int blockType = Random().nextInt(7);
    int orientationIndex = Random().nextInt(4);

    switch (blockType) {
      case 0:
        return IBlock(orientationIndex);
      case 1:
        return JBlock(orientationIndex);
      case 2:
        return LBlock(orientationIndex);
      case 3:
        return OBlock(orientationIndex);
      case 4:
        return TBlock(orientationIndex);
      case 5:
        return SBlock(orientationIndex);
      case 6:
        return ZBlock(orientationIndex);
      default:
        return null;
    }
  }

  void startGame() {
    isPlaying = true;
    score = 0;
    isGameOver = false;
    oldSubBlocks = List<SubBlock>();

    RenderBox renderBoxGame = _keyGameArea.currentContext.findRenderObject();
    subBlockWidth =
        (renderBoxGame.size.width - GAME_AREA_BORDER_WIDTH * 2) / BLOCKS_X;

    block = getNewBlock();

    timer = Timer.periodic(duration, onPlay);
  }

  void endGame() {
    isPlaying = false;
    timer.cancel();
  }

  void onPlay(Timer time) {
    var status = Collision.NONE;

    setState(() {
      if (action != null) {
        if (!checkOnEdge(action)) {
          block.move(action);
        }
      }

      //Evitar que los bloques se choquen
      for (var oldSubBlock in oldSubBlocks) {
        for (var subBlock in block.subBlocks) {
          var x = block.x + subBlock.x;
          var y = block.y + subBlock.y;
          if (x == oldSubBlock.x && y == oldSubBlock.y) {
            switch (action) {
              case BlockMovement.LEFT:
                block.move(BlockMovement.RIGHT);
                break;
              case BlockMovement.RIGHT:
                block.move(BlockMovement.LEFT);
                break;
              case BlockMovement.ROTATE_CLOCKWISE:
                block.move(BlockMovement.ROTATE_COUNTER_CLOCKWISE);
                break;
              default:
                break;
            }
          }
        }
      }

      if (!checkAtBottom()) {
        if (!checkAboveBlock()) {
          block.move(BlockMovement.DOWN);
        } else {
          status = Collision.LANDED_BLOCK;
        }
      } else {
        status = Collision.LANDED;
      }

      if (status == Collision.LANDED_BLOCK && block.y < 0) {
        isGameOver = true;
        endGame();
      } else if (status == Collision.LANDED ||
          status == Collision.LANDED_BLOCK) {
        block.subBlocks.forEach((subBlock) {
          subBlock.x += block.x;
          subBlock.y += block.y;
          oldSubBlocks.add(subBlock);
        });

        block = getNewBlock();
      }

      action = null;
      updateScore();
    });
  }

  void updateScore() {
    var combo = 1;
    Map<int, int> rows = Map();
    List<int> rowsToBeRemoved = List();

    //Eliminar los bloques de las filas caundo haya combo
    oldSubBlocks?.forEach((subBlock) {
      rows.update(subBlock.y, (value) => ++value, ifAbsent: () => 1);
    });

    // Añadir puntaje si una fila esta compelta
    rows.forEach((rowNum, count) {
      if (count == BLOCKS_X) {
        score += combo++;
        print('score: $score');
        rowsToBeRemoved.add(rowNum);
      }
    });

    if (rowsToBeRemoved.length > 0) {
      removeRows(rowsToBeRemoved);
    }
  }

  void removeRows(List<int> rowsToBeRemoved) {
    rowsToBeRemoved.sort();
    rowsToBeRemoved.forEach((rowNum) {
      oldSubBlocks.removeWhere((subBlock) => subBlock.y == rowNum);
      oldSubBlocks.forEach((subBlock) {
        if (subBlock.y < rowNum) {
          ++subBlock.y;
        }
      });
    });
  }

  bool checkAtBottom() {
    return block.y + block.height == BLOCKS_Y;
  }

  bool checkAboveBlock() {
    for (var oldSubBlock in oldSubBlocks) {
      for (var subBlock in block.subBlocks) {
        var x = block.x + subBlock.x;
        var y = block.y + subBlock.y;
        if (x == oldSubBlock.x && y + 1 == oldSubBlock.y) {
          return true;
        }
      }
    }
    return false;
  }

  bool checkOnEdge(BlockMovement action) {
    return (action == BlockMovement.LEFT && block.x <= 0) ||
        (action == BlockMovement.RIGHT && block.x + block.width >= BLOCKS_X);
  }

  Widget getPositionedSquareContainer(Color color, int x, int y) {
    return Positioned(
      left: x * subBlockWidth,
      top: y * subBlockWidth,
      child: Container(
        width: subBlockWidth - SUB_BLOCK_EDGE_WIDTH,
        height: subBlockWidth - SUB_BLOCK_EDGE_WIDTH,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.all(const Radius.circular(3.0)),
        ),
      ),
    );
  }

  Widget drawBlock() {
    if (block == null) return null;
    List<Positioned> subBlocks = List();

    //Bloque actual
    block.subBlocks.forEach((subBlock) {
      subBlocks.add(getPositionedSquareContainer(
          subBlock.color, subBlock.x + block.x, subBlock.y + block.y));
    });

    // Bloques viejos
    oldSubBlocks.forEach((oldSubBlock) {
      subBlocks.add(getPositionedSquareContainer(
          oldSubBlock.color, oldSubBlock.x, oldSubBlock.y));
    });

    if (isGameOver) {
      subBlocks.add(getGameOverReact());
    }

    return Stack(
      children: subBlocks,
    );
  }

  Widget getGameOverReact() {
    return Positioned(
        child: Container(
          width: subBlockWidth * 8.0,
          height: subBlockWidth * 3.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.all(Radius.circular(10.0))),
          child: Text(
            '¡Perdiste!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        left: subBlockWidth * 1.0,
        top: subBlockWidth * 6.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0) {
          action = BlockMovement.RIGHT;
        } else {
          action = BlockMovement.LEFT;
        }
      },
      onTap: () {
        action = BlockMovement.ROTATE_CLOCKWISE;
      },
      child: AspectRatio(
        aspectRatio: BLOCKS_X / BLOCKS_Y,
        child: Container(
          key: _keyGameArea,
          decoration: BoxDecoration(
              color: Colors.indigo[800],
              border: Border.all(
                width: GAME_AREA_BORDER_WIDTH,
                color: Colors.indigoAccent,
              ),
              borderRadius: BorderRadius.all(Radius.circular(10.0))),
          child: drawBlock(),
        ),
      ),
    );
  }
}
