import 'package:flutter/material.dart';
import 'package:wanderwell/theme.dart';

enum WonderCategory {
  place,
  tradition,
  taste,
  story,
  sound,
  person;

  String get label {
    switch (this) {
      case WonderCategory.place:
        return 'Place';
      case WonderCategory.tradition:
        return 'Tradition';
      case WonderCategory.taste:
        return 'Taste';
      case WonderCategory.story:
        return 'Story';
      case WonderCategory.sound:
        return 'Sound';
      case WonderCategory.person:
        return 'Person';
    }
  }

  Color get color {
    switch (this) {
      case WonderCategory.place:
        return AweColors.categoryPlace;
      case WonderCategory.tradition:
        return AweColors.categoryTradition;
      case WonderCategory.taste:
        return AweColors.categoryTaste;
      case WonderCategory.story:
        return AweColors.categoryStory;
      case WonderCategory.sound:
        return AweColors.categorySound;
      case WonderCategory.person:
        return AweColors.categoryPerson;
    }
  }

  IconData get icon {
    switch (this) {
      case WonderCategory.place:
        return Icons.landscape;
      case WonderCategory.tradition:
        return Icons.celebration;
      case WonderCategory.taste:
        return Icons.restaurant;
      case WonderCategory.story:
        return Icons.auto_stories;
      case WonderCategory.sound:
        return Icons.music_note;
      case WonderCategory.person:
        return Icons.person_pin;
    }
  }

  static WonderCategory fromString(String value) {
    return WonderCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WonderCategory.place,
    );
  }
}

enum WonderEmotion {
  awe,
  mystery,
  serenity,
  lostWorlds,
  sacred,
  wild;

  String get label {
    switch (this) {
      case WonderEmotion.awe:
        return 'Awe';
      case WonderEmotion.mystery:
        return 'Mystery';
      case WonderEmotion.serenity:
        return 'Serenity';
      case WonderEmotion.lostWorlds:
        return 'Lost Worlds';
      case WonderEmotion.sacred:
        return 'Sacred';
      case WonderEmotion.wild:
        return 'Wild';
    }
  }

  Color get color {
    switch (this) {
      case WonderEmotion.awe:
        return AweColors.emotionAwe;
      case WonderEmotion.mystery:
        return AweColors.emotionMystery;
      case WonderEmotion.serenity:
        return AweColors.emotionSerenity;
      case WonderEmotion.lostWorlds:
        return AweColors.emotionLostWorlds;
      case WonderEmotion.sacred:
        return AweColors.emotionSacred;
      case WonderEmotion.wild:
        return AweColors.emotionWild;
    }
  }

  static WonderEmotion fromString(String value) {
    final normalized = value.replaceAll('_', '').toLowerCase();
    for (final e in WonderEmotion.values) {
      if (e.name.toLowerCase() == normalized) return e;
    }
    if (value == 'lost_worlds') return WonderEmotion.lostWorlds;
    return WonderEmotion.awe;
  }
}
