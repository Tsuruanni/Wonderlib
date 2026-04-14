import 'package:flutter/material.dart';

/// Centralized icon registry for Owlio.
/// All custom PNG icons are accessed through this class.
/// To change an icon globally, update only the path here.
class AppIcons {
  AppIcons._();

  // ── Navigation ──
  static Widget arrowBack({double size = 24}) => _img('arrow_back_256.png', size);
  static Widget arrowRight({double size = 24}) => _img('arrow_right_64.png', size);
  static Widget arrowLeft({double size = 24}) => _img('arrow_left_256.png', size);
  static Widget close({double size = 24}) => _img('x_outline_256.png', size);

  // ── Bottom Nav ──
  static Widget map({double size = 24}) => _img('map_256.png', size);
  static Widget library({double size = 24}) => _img('library.png', size);
  static Widget clipboard({double size = 24}) => _img('clipboard_256.png', size);
  static Widget card({double size = 24}) => _img('card.png', size);
  static Widget trophy({double size = 24}) => _img('trophy_256.png', size);

  // ── Stats / Currency ──
  static Widget gem({double size = 24}) => _img('gem_outline_256.png', size);
  static Widget xp({double size = 24}) => _img('xp_green_outline.png', size);
  static Widget star({double size = 24}) => _img('star.png', size);

  // ── Streak ──
  static Widget fire({double size = 24}) => _img('fire_256.png', size);
  static Widget fireBlue({double size = 24}) => _img('fire_blue_256.png', size);
  static Widget fireMenu({double size = 24}) => _img('fire_menu_bar_256.png', size);

  // ── Content ──
  static Widget book({double size = 24}) => _img('book_brown_256.png', size);
  static Widget vocabulary({double size = 24}) => _img('vocabulary.png', size);
  static Widget quiz({double size = 24}) => _img('quiz.png', size);

  // ── Audio ──
  static Widget soundOn({double size = 24}) => _img('sound.png', size);
  static Widget soundOff({double size = 24}) => _img('sound_off_256.png', size);

  // ── Status ──
  static Widget check({double size = 24}) => _img('check_mark_256.png', size);
  static Widget warning({double size = 24}) => _img('warning_sign_outline_256.png', size);
  static Widget schedule({double size = 24}) => _img('schedule.png', size);

  // ── League Ranks ──
  static Widget rankBronze({double size = 24}) => _img('rank-bronze-1_large.png', size);
  static Widget rankSilver({double size = 24}) => _img('rank-silver-2_large.png', size);
  static Widget rankGold({double size = 24}) => _img('rank-gold-3_large.png', size);
  static Widget rankPlatinum({double size = 24}) => _img('rank-platinum-5_large.png', size);
  static Widget rankDiamond({double size = 24}) => _img('rank-diamond-7_large.png', size);

  // ── Special ──
  static Widget quest({double size = 90}) => _img('quest.png', size);
  static Widget ukFlag({double size = 32}) => _img('uk-flag.png', size);

  // ── Learning Path Nodes ──
  static Widget vocabNode(String state, {double size = 64}) => _img('voc_$state.png', size);
  static Widget bookNode(String state, {double size = 64}) => _img('book_$state.png', size);
  static Widget gameNode(String state, {double size = 64}) => _img('game_$state.png', size);
  static Widget treasureNode(String state, {double size = 64}) => _img('treasure_$state.png', size);
  static Widget unitNode({double size = 64}) => _img('unit_nodes.png', size);
  static Widget unitNodePressed({double size = 64}) => _img('unit_nodes_pressed.png', size);

  // ── Internal ──
  static Widget _img(String name, double size) => Image.asset(
    'assets/icons/$name',
    width: size,
    height: size,
    filterQuality: FilterQuality.high,
  );
}
