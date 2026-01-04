import 'package:equatable/equatable.dart';

enum AppTab { home, scan, docs, filter, settings }
enum ReadingState { idle, playing, paused }

class AppState extends Equatable {
  final AppTab currentTab;
  final List<Document> recentDocuments;
  final Document? currentDocument;
  final ReadingState readingState;
  final bool isSoundEnabled;
  final bool isBookmarked;
  final bool isFontEnabled;
  final bool isHighlighted;
  final double readingSpeed;
  final double volume;
  final double pitch;
  final int currentWordIndex;
  final int selectedTextColor;
  final int selectedBackgroundColor;
  final String userName;
  
  const AppState({
    this.currentTab = AppTab.home,
    this.recentDocuments = const [],
    this.currentDocument,
    this.readingState = ReadingState.idle,
    this.isSoundEnabled = true,
    this.isBookmarked = false,
    this.isFontEnabled = true,
    this.isHighlighted = false,
    this.readingSpeed = 0.5,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.currentWordIndex = 0,
    this.selectedTextColor = 0,
    this.selectedBackgroundColor = 0,
    this.userName = 'Archita',
  });

  @override
  List<Object?> get props => [
    currentTab,
    recentDocuments,
    currentDocument,
    readingState,
    isSoundEnabled,
    isBookmarked,
    isFontEnabled,
    isHighlighted,
    readingSpeed,
    volume,
    pitch,
    currentWordIndex,
    selectedTextColor,
    selectedBackgroundColor,
    userName,
  ];

  AppState copyWith({
    AppTab? currentTab,
    List<Document>? recentDocuments,
    Document? currentDocument,
    ReadingState? readingState,
    bool? isSoundEnabled,
    bool? isBookmarked,
    bool? isFontEnabled,
    bool? isHighlighted,
    double? readingSpeed,
    double? volume,
    double? pitch,
    int? currentWordIndex,
    int? selectedTextColor,
    int? selectedBackgroundColor,
    String? userName,
  }) {
    return AppState(
      currentTab: currentTab ?? this.currentTab,
      recentDocuments: recentDocuments ?? this.recentDocuments,
      currentDocument: currentDocument ?? this.currentDocument,
      readingState: readingState ?? this.readingState,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFontEnabled: isFontEnabled ?? this.isFontEnabled,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      readingSpeed: readingSpeed ?? this.readingSpeed,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      selectedTextColor: selectedTextColor ?? this.selectedTextColor,
      selectedBackgroundColor: selectedBackgroundColor ?? this.selectedBackgroundColor,
      userName: userName ?? this.userName,
    );
  }
}

class Document {
  final String id;
  final String name;
  final String previewPath;
  final DateTime uploadedDate;
  final String content;
  
  Document({
    required this.id,
    required this.name,
    required this.previewPath,
    required this.uploadedDate,
    this.content = '',
  });
}