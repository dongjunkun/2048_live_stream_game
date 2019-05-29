import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_game_example/model.dart';
import 'package:puzzle_game_example/simple_animations_package.dart';
import 'package:puzzle_game_example/utils.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  GlobalKey<ScaffoldState> _globalKey = GlobalKey();
  int lastTime = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '2048小游戏',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: WillPopScope(
            child: Scaffold(
              key: _globalKey,
              body: Stack(
                children: <Widget>[
                  Positioned.fill(child: AnimatedBackground()),
                  Positioned.fill(child: Particles(15)),
                  Positioned.fill(child: BoardWidget()),
                ],
              ),
            ),
            onWillPop: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                int newTime = DateTime.now().millisecondsSinceEpoch;
                int result = newTime - lastTime;
                lastTime = newTime;
                if (result > 2000) {
                  _globalKey.currentState
                      .showSnackBar(SnackBar(content: Text('再按一次退出游戏！')));
                } else {
                  SystemNavigator.pop();
                }
              }
              return null;
            }));
  }
}

class Particles extends StatefulWidget {
  final int numberOfParticles;

  Particles(this.numberOfParticles);

  @override
  _ParticlesState createState() => _ParticlesState();
}

class _ParticlesState extends State<Particles> {
  final Random random = Random();

  final List<ParticleModel> particles = [];

  @override
  void initState() {
    List.generate(widget.numberOfParticles, (index) {
      particles.add(ParticleModel(random));
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Rendering(
      startTime: Duration(seconds: 30),
      onTick: _simulateParticles,
      builder: (context, time) {
        return CustomPaint(
          painter: ParticlePainter(particles, time),
        );
      },
    );
  }

  _simulateParticles(Duration time) {
    particles.forEach((particle) => particle.maintainRestart(time));
  }
}

class ParticleModel {
  Animatable tween;
  double size;
  AnimationProgress animationProgress;
  Random random;

  ParticleModel(this.random) {
    restart();
  }

  restart({Duration time = Duration.zero}) {
    final startPosition = Offset(-0.2 + 1.4 * random.nextDouble(), 1.2);
    final endPosition = Offset(-0.2 + 1.4 * random.nextDouble(), -0.2);
    final duration = Duration(milliseconds: 10000 + random.nextInt(6000));

    tween = MultiTrackTween([
      Track("x").add(
          duration, Tween(begin: startPosition.dx, end: endPosition.dx),
          curve: Curves.easeInOutSine),
      Track("y").add(
          duration, Tween(begin: startPosition.dy, end: endPosition.dy),
          curve: Curves.easeIn),
    ]);
    animationProgress = AnimationProgress(duration: duration, startTime: time);
    size = 0.2 + random.nextDouble() * 0.4;
  }

  maintainRestart(Duration time) {
    if (animationProgress.progress(time) == 1.0) {
      restart(time: time);
    }
  }
}

class ParticlePainter extends CustomPainter {
  List<ParticleModel> particles;
  Duration time;

  ParticlePainter(this.particles, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withAlpha(50);

    particles.forEach((particle) {
      var progress = particle.animationProgress.progress(time);
      final animation = particle.tween.transform(progress);
      final position =
          Offset(animation["x"] * size.width, animation["y"] * size.height);
      canvas.drawCircle(position, size.width * 0.2 * particle.size, paint);
    });
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class AnimatedBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tween = MultiTrackTween([
      Track("color1").add(Duration(seconds: 3),
          ColorTween(begin: Color(0xff8a113a), end: Colors.lightBlue.shade900)),
      Track("color2").add(Duration(seconds: 3),
          ColorTween(begin: Color(0xff440216), end: Colors.blue.shade600))
    ]);

    return ControlledAnimation(
      playback: Playback.MIRROR,
      tween: tween,
      duration: tween.duration,
      builder: (context, animation) {
        return Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [animation["color1"], animation["color2"]])),
        );
      },
    );
  }
}

class MyHomePage extends StatelessWidget {
  final _BoardWidgetState state;

  const MyHomePage({this.state});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    Size boardSize = state.boardSize();
    double width = (boardSize.width - (state.column + 1) * state.tilePadding) /
        state.column;

    List<TileBox> backgroundBox = List<TileBox>();
    for (int r = 0; r < state.row; ++r) {
      for (int c = 0; c < state.column; ++c) {
        TileBox tile = TileBox(
          left: c * width * state.tilePadding * (c + 1),
          top: r * width * state.tilePadding * (r + 1),
          size: width,
        );
        backgroundBox.add(tile);
      }
    }

    return Positioned(
      left: 0.0,
      top: 0,
      child: Container(
        width: state.boardSize().width,
        height: state.boardSize().width,
        decoration: BoxDecoration(
            color: Colors.blueGrey, borderRadius: BorderRadius.circular(6.0)),
        child: Stack(
          children: backgroundBox,
        ),
      ),
    );
  }
}

class BoardWidget extends StatefulWidget {
  @override
  _BoardWidgetState createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  Board _board;
  int row;
  int column;
  bool _isMoving;
  bool gameOver;
  double tilePadding = 5.0;
  MediaQueryData _queryData;

  @override
  void initState() {
    super.initState();

    row = 4;
    column = 4;
    _isMoving = false;
    gameOver = false;

    _board = Board(row, column);
    newGame();
  }

  void newGame() {
    setState(() {
      _board.initBoard();
      gameOver = false;
    });
  }

  void gameover() {
    setState(() {
      if (_board.gameOver()) {
        gameOver = true;
      }
    });
  }

  Size boardSize() {
    Size size = _queryData.size;
    if (size.width < 480) {
      return Size(size.width, size.width);
    } else {
      return Size(480, 480);
    }
  }

  @override
  Widget build(BuildContext context) {
    _queryData = MediaQuery.of(context);
    List<TileWidget> _tileWidgets = List<TileWidget>();
    for (int r = 0; r < row; ++r) {
      for (int c = 0; c < column; ++c) {
        _tileWidgets.add(TileWidget(tile: _board.getTile(r, c), state: this));
      }
    }
    List<Widget> children = List<Widget>();

    children.add(MyHomePage(state: this));
    children.addAll(_tileWidgets);

    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: boardSize().width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Image.asset(
                    'asset/icon/icon.png',
                    width: 100,
                    height: 100,
                  ),
                  Container(
                    width: 100,
                    height: 80,
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        color: Colors.orange[100],
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(Radius.circular(20))),
                    child: Center(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          "分数",
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.black54,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${_board.score}",
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.black54,
                              fontWeight: FontWeight.bold),
                        )
                      ],
                    )),
                  ),
                  FlatButton(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          color: Colors.orange[100]),
                      child: Center(
                        child: Text(
                          "新游戏",
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.black54,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    onPressed: () {
                      newGame();
                    },
                  )
                ],
              ),
            ),
          ),
          Container(
            width: boardSize().width,
            padding: EdgeInsets.all(16),
            child: Opacity(
                opacity: gameOver ? 1.0 : 0.0,
                child: Center(
                  child: Text(
                    '游戏结束',
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold),
                  ),
                )),
          ),
          Center(
            child: Container(
              width: boardSize().width - 20,
              height: boardSize().width - 20,
              child: GestureDetector(
                onVerticalDragUpdate: (detail) {
                  if (detail.delta.distance == 0 || _isMoving) {
                    return;
                  }
                  _isMoving = true;
                  if (detail.delta.direction > 0) {
                    setState(() {
                      _board.moveDown();
                      gameover();
                    });
                  } else {
                    setState(() {
                      _board.moveUp();
                      gameover();
                    });
                  }
                },
                onVerticalDragEnd: (d) {
                  _isMoving = false;
                },
                onVerticalDragCancel: () {
                  _isMoving = false;
                },
                onHorizontalDragUpdate: (d) {
                  if (d.delta.distance == 0 || _isMoving) {
                    return;
                  }
                  _isMoving = true;
                  if (d.delta.direction > 0) {
                    setState(() {
                      _board.moveLeft();
                      gameover();
                    });
                  } else {
                    setState(() {
                      _board.moveRight();
                      gameover();
                    });
                  }
                },
                onHorizontalDragEnd: (d) {
                  _isMoving = false;
                },
                onHorizontalDragCancel: () {
                  _isMoving = false;
                },
                child: Stack(
                  children: children,
                ),
              ),
            ),
          )
        ],
    );
  }
}

class TileWidget extends StatefulWidget {
  final Tile tile;
  final _BoardWidgetState state;

  const TileWidget({Key key, this.tile, this.state}) : super(key: key);

  @override
  _TileWidgetState createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget>
    with SingleTickerProviderStateMixin {
  AnimationController controller;
  Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: Duration(
        milliseconds: 200,
      ),
      vsync: this,
    );

    animation = Tween(begin: 0.0, end: 1.0).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
    widget.tile.isNew = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tile.isNew && !widget.tile.isEmpty()) {
      controller.reset();
      controller.forward();
      widget.tile.isNew = false;
    } else {
      controller.animateTo(1.0);
    }

    return AnimatedTileWidget(
      tile: widget.tile,
      state: widget.state,
      animation: animation,
    );
  }
}

class AnimatedTileWidget extends AnimatedWidget {
  final Tile tile;
  final _BoardWidgetState state;

  AnimatedTileWidget({
    Key key,
    this.tile,
    this.state,
    Animation<double> animation,
  }) : super(
          key: key,
          listenable: animation,
        );

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = listenable;
    double animationValue = animation.value;
    Size boardSize = state.boardSize();
    double width =
        (boardSize.width - 20 - (state.column + 1) * state.tilePadding) /
            state.column;

    if (tile.value == 0) {
      return Positioned(
          left: (tile.column * width + state.tilePadding * (tile.column + 1)) +
              width / 2 * (1 - animationValue),
          top: tile.row * width +
              state.tilePadding * (tile.row + 1) +
              width / 2 * (1 - animationValue),
          child: Container(
            decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.all(Radius.circular(5))),
            height: width,
            width: width,
          ));
    } else {
      return TileBox(
        left: (tile.column * width + state.tilePadding * (tile.column + 1)) +
            width / 2 * (1 - animationValue),
        top: tile.row * width +
            state.tilePadding * (tile.row + 1) +
            width / 2 * (1 - animationValue),
        size: width * animationValue,
        color: tileColors.containsKey(tile.value)
            ? tileColors[tile.value]
            : Colors.orange[50],
        text: Text(
          '${tile.value}',
          style: TextStyle(
              fontSize: 25, color: Colors.black54, fontWeight: FontWeight.bold),
        ),
      );
    }
  }
}

class TileBox extends StatelessWidget {
  final double left;
  final double top;
  final double size;
  final Color color;
  final Text text;

  const TileBox({
    Key key,
    this.left,
    this.top,
    this.size,
    this.color,
    this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          color: color,
        ),
        child: Center(
          child: text,
        ),
      ),
    );
  }
}
